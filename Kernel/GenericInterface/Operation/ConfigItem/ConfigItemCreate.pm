# --
# Kernel/GenericInterface/Operation/CI/ConfigItemCreate.pm - GenericInterface ConfigItem ConfigItemCreate operation backend
# Copyright (C) 2001-2014 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::GenericInterface::Operation::ConfigItem::ConfigItemCreate;

use strict;
use warnings;

use Kernel::System::GeneralCatalog;
use Kernel::System::ITSMConfigItem;

use Kernel::GenericInterface::Operation::Common;
use Kernel::GenericInterface::Operation::ConfigItem::Common;
use Kernel::System::VariableCheck qw(:all);

=head1 NAME

Kernel::GenericInterface::Operation::ConfigItem::ConfigItemCreate - GenericInterface ConfigItem ConfigItemCreate Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::GenericInterface::Operation->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (
        qw(
        DebuggerObject ConfigObject MainObject LogObject TimeObject DBObject EncodeObject
        WebserviceID
        )
        )
    {
        if ( !$Param{$Needed} ) {
            return {
                Success      => 0,
                ErrorMessage => "Got no $Needed!"
            };
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    $Self->{OperationName} = 'ConfigItemCreate';

    # create additional objects
    $Self->{GeneralCatalogObject} = Kernel::System::GeneralCatalog->new( %{$Self} );
    $Self->{ConfigItemObject}     = Kernel::System::ITSMConfigItem->new( %{$Self} );
    $Self->{CommonObject}         = Kernel::GenericInterface::Operation::Common->new( %{$Self} );
    $Self->{ConfigItemCommonObject}
        = Kernel::GenericInterface::Operation::ConfigItem::Common->new( %{$Self} );

    $Self->{Config} = $Self->{ConfigObject}->Get('GenericInterface::Operation::ConfigItemCreate');

    $Self->{Config}->{DefaultValue} = 'Not Defined';

    # get a list of all config item classes
    $Self->{ClassList} = $Self->{GeneralCatalogObject}->ItemList(
        Class => 'ITSM::ConfigItem::Class',
    );

    if ( !IsHashRefWithData( $Self->{ClassList} ) ) {
        return $Self->{DebuggerObject}->Error(
            Summary => 'Error when trying to get class listing of ITSM::ConfigItem::Class',
        );
    }

    # get a list of all incistates
    $Self->{InciStateList} = $Self->{GeneralCatalogObject}->ItemList(
        Class => 'ITSM::Core::IncidentState',
    );

    if ( !IsHashRefWithData( $Self->{InciStateList} ) ) {
        return $Self->{DebuggerObject}->Error(
            Summary => 'Error when trying to get incident state listing of'
                . ' ITSM::Core::IncidentState',
        );
    }

    # get a list of all deplstates
    $Self->{DeplStateList} = $Self->{GeneralCatalogObject}->ItemList(
        Class => 'ITSM::ConfigItem::DeploymentState',
    );

    if ( !IsHashRefWithData( $Self->{DeplStateList} ) ) {
        return $Self->{DebuggerObject}->Error(
            Summary => 'Error when trying to get incident state listing of'
                . ' ITSM::ConfigItem::DeploymentState',
        );
    }

    # also provide the classlist in reversed form for easier reverse lookups
    my %ReverseClassList = reverse %{ $Self->{ClassList} };
    $Self->{ReverseClassList} = \%ReverseClassList;

    # also provide the incistatelist in reversed form for easier reverse lookups
    my %ReverseInciStateList = reverse %{ $Self->{InciStateList} };
    $Self->{ReverseInciStateList} = \%ReverseInciStateList;

    # also provide the deplstatelist in reversed form for easier reverse lookups
    my %ReverseDeplStateList = reverse %{ $Self->{DeplStateList} };
    $Self->{ReverseDeplStateList} = \%ReverseDeplStateList;

    return $Self;
}

=item Run()

perform ConfigItemCreate Operation. This will return the created config item number.

    my $Result = $OperationObject->Run(
        Data => {
            UserLogin         => 'some agent login',        # UserLogin or CustomerUserLogin or SessionID is
                                                            #   required
            SessionID         => 123,

            Password  => 'some password',                   # if UserLogin or CustomerUserLogin is sent then
                                                            #   Password is required
            ConfigItem => {
                Class        => 'Config Item Class',
                Name         => 'The Name',
                DeplState    => 'deployment state',
                InciState    => 'incident state',
                CIXMLData    => $ArrayHashRef,              # it deppends on the Configuration Item class and definition

                Attachment => [
                    {
                        Content     => 'content'            # base64 encoded
                        ContentType => 'some content type'
                        Filename    => 'some fine name'
                    },
                    # ...
                ],
                #or
                #Attachment => {
                #    Content     => 'content'
                #    ContentType => 'some content type'
                #    Filename    => 'some fine name'
                #},
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        ErrorMessage    => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            ConfigItemID => 123,                    # Configuration Item  ID number in OTRS::ITSM (Service desk system)
            Number       => 2324454323322           # Configuration Item  Number in OTRS::ITSM (Service desk system)
            Error => {                              # should not return errors
                    ErrorCode    => 'ConfigItem.Create.ErrorCode'
                    ErrorMessage => 'Error Description'
            },
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if (
        !$Param{Data}->{UserLogin}
        && !$Param{Data}->{SessionID}
        )
    {
        return $Self->{ConfigItemCommonObject}->ReturnError(
            ErrorCode => "$Self->{OperationName}.MissingParameter",
            ErrorMessage =>
                "$Self->{OperationName}: UserLogin, CustomerUserLogin or SessionID is required!",
        );
    }

    if ( $Param{Data}->{UserLogin} ) {

        if ( !$Param{Data}->{Password} )
        {
            return $Self->{ConfigItemCommonObject}->ReturnError(
                ErrorCode    => "$Self->{OperationName}.MissingParameter",
                ErrorMessage => "$Self->{OperationName}: Password or SessionID is required!",
            );
        }
    }

    # authenticate user
    my ( $UserID, $UserType ) = $Self->{CommonObject}->Auth(%Param);

    if ( !$UserID ) {
        return $Self->{ConfigItemCommonObject}->ReturnError(
            ErrorCode    => "$Self->{OperationName}.AuthFail",
            ErrorMessage => "$Self->{OperationName}: User could not be authenticated!",
        );
    }

    # check needed hashes
    for my $Needed (qw(ConfigItem)) {
        if ( !IsHashRefWithData( $Param{Data}->{$Needed} ) ) {
            return $Self->{ConfigItemCommonObject}->ReturnError(
                ErrorCode => "$Self->{OperationName}.MissingParameter",
                ErrorMessage =>
                    "$Self->{OperationName}: $Needed parameter is missing or not valid!",
            );
        }
    }

    # isolate config item parameter
    my $ConfigItem = $Param{Data}->{ConfigItem};

    # remove leading and trailing spaces
    for my $Attribute ( sort keys %{$ConfigItem} ) {
        if ( ref $Attribute ne 'HASH' && ref $Attribute ne 'ARRAY' ) {

            #remove leading spaces
            $ConfigItem->{$Attribute} =~ s{\A\s+}{};

            #remove trailing spaces
            $ConfigItem->{$Attribute} =~ s{\s+\z}{};
        }
    }
    if ( !IsHashRefWithData( $ConfigItem->{CIXMLData} ) ) {
        return $Self->{ConfigItemCommonObject}->ReturnError(
            ErrorCode    => "$Self->{OperationName}.MissingParameter",
            ErrorMessage => "$Self->{OperationName}: ConfigItem->CIXMLData is missing or invalid!",
        );
    }

    # remove leading and trailing spaces for CIXMLData
    $Self->_CleanXMLData( XMLData => $ConfigItem->{CIXMLData} );

    # check ConfigItem attribute values
    my $ConfigItemCheck = $Self->_CheckConfigItem( ConfigItem => $ConfigItem );

    if ( !$ConfigItemCheck->{Success} ) {
        return $Self->{ConfigItemCommonObject}->ReturnError( %{$ConfigItemCheck} );
    }

    # check create permissions
    my $Permission = $Self->{ConfigItemObject}->Permission(
        Scope   => 'Class',
        ClassID => $Self->{ReverseClassList}->{ $ConfigItem->{Class} },
        UserID  => $UserID,
        Type    => $Self->{Config}->{Permission},
    );

    if ( !$Permission ) {
        return $Self->{ConfigItemCommonObject}->ReturnError(
            ErrorCode    => "$Self->{OperationName}.AccessDenied",
            ErrorMessage => "$Self->{OperationName}: Can not create configuration items!",
        );
    }

    my $Attachment;
    my @AttachmentList;

    if ( defined $Param{Data}->{ConfigItem}->{Attachment} ) {

        # isolate Attachment parameter
        $Attachment = delete $Param{Data}->{ConfigItem}->{Attachment};

        # homologate imput to array
        if ( IsHashRefWithData($Attachment) ) {
            push @AttachmentList, $Attachment;
        }
        elsif ( IsArrayRefWithData($Attachment) ) {
            @AttachmentList = @{$Attachment};
        }
        else {
            return $Self->{ConfigItemCommonObject}->ReturnError(
                ErrorCode => "$Self->{OperationName}.InvalidParameter",
                ErrorMessage =>
                    "$Self->{OperationName}: ConfigItem->Attachment parameter is invalid!",
            );
        }

        # check Attachment internal structure
        for my $AttachmentItem (@AttachmentList) {
            if ( !IsHashRefWithData($AttachmentItem) ) {
                return $Self->{ConfigItemCommonObject}->ReturnError(
                    ErrorCode => "$Self->{OperationName}.InvalidParameter",
                    ErrorMessage =>
                        "$Self->{OperationName}: ConfigItem->Attachment parameter is invalid!",
                );
            }

            # remove leading and trailing spaces
            for my $Attribute ( sort keys %{$AttachmentItem} ) {
                if ( ref $Attribute ne 'HASH' && ref $Attribute ne 'ARRAY' ) {

                    #remove leading spaces
                    $AttachmentItem->{$Attribute} =~ s{\A\s+}{};

                    #remove trailing spaces
                    $AttachmentItem->{$Attribute} =~ s{\s+\z}{};
                }
            }

            # check Attachment attribute values
            my $AttachmentCheck = $Self->_CheckAttachment( Attachment => $AttachmentItem );

            if ( !$AttachmentCheck->{Success} ) {
                return $Self->{ConfigItemCommonObject}->ReturnError( %{$AttachmentCheck} );
            }
        }
    }

    return $Self->_ConfigItemCreate(
        ConfigItem     => $ConfigItem,
        AttachmentList => \@AttachmentList,
        UserID         => $UserID,
    );
}

=begin Internal:

=item _CleanXMLData()

removed trailing and leading white spaces in the XMLData.

    my $XMLDataClean = $OperationObject->_CleanXMLData(
        Definition => $DefinitionArrayRef,          # Config Item Definition ot just part of it
        XMLData    => $XMLDataHashRef,
    );

    returns:

    $XMLDataClean = {
        Success => 1,                               # if everything is OK
    }

    $XMLDataClean = {
        ErrorCode    => 'Function.Error',           # if error
        ErrorMessage => 'Error description',
    }

=cut

sub _CleanXMLData {
    my ( $Self, %Param ) = @_;

    my $XMLData = $Param{XMLData};

    KEY:
    for my $Key ( sort keys %{$XMLData} ) {
        if ( ref $XMLData->{$Key} eq 'ARRAY' ) {
            ELEMENT:
            for my $Element ( @{ $XMLData->{$Key} } ) {
                if ( ref $Element eq 'HASH' ) {

                    # start recursion
                    $Self->_CleanXMLData( XMLData => $Element );
                    next ELEMENT;
                }
                elsif ( ref $Element eq '' ) {

                    #remove leading spaces
                    $Element =~ s{\A\s+}{};

                    #remove trailing spaces
                    $Element =~ s{\s+\z}{};
                }
            }
        }
        elsif ( ref $XMLData->{$Key} eq 'HASH' ) {

            # start recursion
            $Self->_CleanXMLData( XMLData => $XMLData->{$Key} );
            next KEY;

        }
        elsif ( ref $XMLData->{$Key} eq '' ) {

            #remove leading spaces
            $XMLData->{$Key} =~ s{\A\s+}{};

            #remove trailing spaces
            $XMLData->{$Key} =~ s{\s+\z}{};
        }
    }
}

=item _CheckConfigItem()

checks if the given config item parameters are valid.

    my $ConfigItemCheck = $OperationObject->_CheckConfigItem(
        ConfigItem => $ConfigItem,                  # all config item parameters
    );

    returns:

    $ConfigItemCheck = {
        Success => 1,                               # if everything is OK
    }

    $ConfigItemCheck = {
        ErrorCode    => 'Function.Error',           # if error
        ErrorMessage => 'Error description',
    }

=cut

sub _CheckConfigItem {
    my ( $Self, %Param ) = @_;

    my $ConfigItem = $Param{ConfigItem};

    # check config item internally
    for my $Needed (qw(Class Name DeplState InciState CIXMLData)) {
        if ( !$ConfigItem->{$Needed} ) {
            return {
                ErrorCode    => "$Self->{OperationName}.MissingParameter",
                ErrorMessage => "$Self->{OperationName}: ConfigItem->$Needed parameter is missing!",
            };
        }
    }

    # check ConfigItem->Class
    if ( !$Self->{ConfigItemCommonObject}->ValidateClass( %{$ConfigItem} ) ) {
        return {
            ErrorCode => "$Self->{OperationName}.InvalidParameter",
            ErrorMessage =>
                "$Self->{OperationName}: ConfigItem->Class parameter is invalid!",
        };
    }

    # check ConfigItem->DeplState
    if ( !$Self->{ConfigItemCommonObject}->ValidateDeplState( %{$ConfigItem} ) ) {
        return {
            ErrorCode => "$Self->{OperationName}.InvalidParameter",
            ErrorMessage =>
                "$Self->{OperationName}: ConfigItem->DeplState parameter is invalid!",
        };
    }

    # check ConfigItem->DeplState
    if ( !$Self->{ConfigItemCommonObject}->ValidateInciState( %{$ConfigItem} ) ) {
        return {
            ErrorCode => "$Self->{OperationName}.InvalidParameter",
            ErrorMessage =>
                "$Self->{OperationName}: ConfigItem->InciState parameter is invalid!",
        };
    }

    # get last config item defintion
    my $DefinitionData = $Self->{ConfigItemObject}->DefinitionGet(
        ClassID => $Self->{ReverseClassList}->{ $ConfigItem->{Class} },
    );

    my $XMLDataCheckResult = $Self->{ConfigItemCommonObject}->CheckXMLData(
        Definition => $DefinitionData->{DefinitionRef},
        XMLData    => $ConfigItem->{CIXMLData},
    );

    if ( !$XMLDataCheckResult->{Success} ) {
        return $XMLDataCheckResult;
    }

    # if everything is OK then return Success
    return {
        Success => 1,
    };
}

=item _CheckAttachment()

checks if the given attachment parameter is valid.

    my $AttachmentCheck = $OperationObject->_CheckAttachment(
        Attachment => $Attachment,                  # all attachment parameters
    );

    returns:

    $AttachmentCheck = {
        Success => 1,                               # if everething is OK
    }

    $AttachmentCheck = {
        ErrorCode    => 'Function.Error',           # if error
        ErrorMessage => 'Error description',
    }

=cut

sub _CheckAttachment {
    my ( $Self, %Param ) = @_;

    my $Attachment = $Param{Attachment};

    # check attachment item internally
    for my $Needed (qw(Content ContentType Filename)) {
        if ( !$Attachment->{$Needed} ) {
            return {
                ErrorCode => "$Self->{OperationName}.MissingParameter",
                ErrorMessage =>
                    "$Self->{OperationName}: Attachment->$Needed  parameter is missing!",
            };
        }
    }

    # check Article->ContentType
    if ( $Attachment->{ContentType} ) {

        $Attachment->{ContentType} = lc $Attachment->{ContentType};

        # check Charset part
        my $Charset = '';
        if ( $Attachment->{ContentType} =~ /charset=/i ) {
            $Charset = $Attachment->{ContentType};
            $Charset =~ s/.+?charset=("|'|)(\w+)/$2/gi;
            $Charset =~ s/"|'//g;
            $Charset =~ s/(.+?);.*/$1/g;
        }

        if ( $Charset && !$Self->{ConfigItemCommonObject}->ValidateCharset( Charset => $Charset ) )
        {
            return {
                ErrorCode    => "$Self->{OperationName}.InvalidParameter",
                ErrorMessage => "$Self->{OperationName}: Attachment->ContentType is invalid!",
            };
        }

        # check MimeType part
        my $MimeType = '';
        if ( $Attachment->{ContentType} =~ /^(\w+\/\w+)/i ) {
            $MimeType = $1;
            $MimeType =~ s/"|'//g;
        }

        if ( !$Self->{ConfigItemCommonObject}->ValidateMimeType( MimeType => $MimeType ) ) {
            return {
                ErrorCode    => "$Self->{OperationName}.InvalidParameter",
                ErrorMessage => "$Self->{OperationName}: Attachment->ContentType is invalid!",
            };
        }
    }

    # if everything is OK then return Success
    return {
        Success => 1,
    };
}

=item _ConfigItemCreate()

creates a configuration item with attachments if specified.

    my $Response = $OperationObject->_ConfigItemCreate(
        ConfigItem     => $ConfigItem,             # all configuration item parameters
        AttachmentList => $Attachment,             # a list of all attachments
        UserID         => 123,
    );

    returns:

    $Response = {
        Success => 1,                               # if everething is OK
        Data => {
            ConfigItemID => 123,
            ConfigItemNumber => 'CN123',
        }
    }

    $Response = {
        Success      => 0,                         # if unexpected error
        ErrorMessage => "$Param{ErrorCode}: $Param{ErrorMessage}",
    }

=cut

sub _ConfigItemCreate {
    my ( $Self, %Param ) = @_;

    my $ConfigItem     = $Param{ConfigItem};
    my $AttachmentList = $Param{AttachmentList};

    my $DeplStateID = $Self->{ReverseDeplStateList}->{ $ConfigItem->{DeplState} };
    my $InciStateID = $Self->{ReverseInciStateList}->{ $ConfigItem->{InciState} };

    my $RawXMLData = $ConfigItem->{CIXMLData};

    # get last config item defintion
    my $DefinitionData = $Self->{ConfigItemObject}->DefinitionGet(
        ClassID => $Self->{ReverseClassList}->{ $ConfigItem->{Class} },
    );

    # replace date, date time, customer, company and general catalog values
    my $ReplacedXMLData = $Self->{ConfigItemCommonObject}->ReplaceXMLData(
        XMLData    => $RawXMLData,
        Definition => $DefinitionData->{DefinitionRef},
    );

    # create an XMLData structure suitable for VersionAdd
    my $XMLData = $Self->{ConfigItemCommonObject}->FormatXMLData(
        XMLData => $ReplacedXMLData,
    );

    # create new config item
    my $ConfigItemID = $Self->{ConfigItemObject}->ConfigItemAdd(
        ClassID => $Self->{ReverseClassList}->{ $ConfigItem->{Class} },
        UserID  => $Param{UserID},
    );

    my $VersionID = $Self->{ConfigItemObject}->VersionAdd(
        ConfigItemID => $ConfigItemID,
        Name         => $ConfigItem->{Name},
        DefinitionID => $DefinitionData->{DefinitionID},
        DeplStateID  => $DeplStateID,
        InciStateID  => $InciStateID,
        XMLData      => $XMLData,
        UserID       => $Param{UserID},
    );

    if ( !$ConfigItemID && !$VersionID ) {
        return {
            Success      => 0,
            ErrorMessage => 'Configuration Item could not be created, please contact the system'
                . 'administrator'
            }
    }

    # set attachments
    if ( IsArrayRefWithData($AttachmentList) ) {

        for my $Attachment ( @{$AttachmentList} ) {
            my $Result = $Self->{ConfigItemCommonObject}->CreateAttachment(
                Attachment   => $Attachment,
                ConfigItemID => $ConfigItemID,
                UserID       => $Param{UserID}
            );

            if ( !$Result->{Success} ) {
                my $ErrorMessage =
                    $Result->{ErrorMessage} || "Attachment could not be created, please contact"
                    . " the system administrator";

                return {
                    Success      => 0,
                    ErrorMessage => $ErrorMessage,
                };
            }
        }
    }

    # get ConfigItem data
    my $ConfigItemData = $Self->{ConfigItemObject}->ConfigItemGet(
        ConfigItemID => $ConfigItemID,
    );

    if ( !IsHashRefWithData($ConfigItemData) ) {
        return {
            Success      => 0,
            ErrorMessage => 'Could not get new configuration item information, please contact the'
                . ' system administrator',
            }
    }

    return {
        Success => 1,
        Data    => {
            ConfigItemID => $ConfigItemID,
            Number       => $ConfigItemData->{Number},
        },
    };
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<http://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut