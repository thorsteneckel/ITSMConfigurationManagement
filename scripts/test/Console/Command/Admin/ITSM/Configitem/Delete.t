# --
# Copyright (C) 2001-2016 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

## no critic (Modules::RequireExplicitPackage)
use strict;
use warnings;
use utf8;

use vars (qw($Self));

my $CommandObject = $Kernel::OM->Get('Kernel::System::Console::Command::Admin::ITSM::Configitem::Delete');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

my $ExitCode = $CommandObject->Execute();

$Self->Is(
    $ExitCode,
    1,
    "Admin::ITSM::Configitem::Delete exit code without options",
);

# check command with option --all and argument --accept n ( cancel deleting all config item)
$ExitCode = $CommandObject->Execute( '--all', 'n' );

$Self->Is(
    $ExitCode,
    0,
    "Option '--all' n",
);

# check command with class options (invalid class)
my $RandomClass = 'TestClass' . $Helper->GetRandomID();
$ExitCode = $CommandObject->Execute( '--class', $RandomClass );

$Self->Is(
    $ExitCode,
    1,
    "Option 'class' (but class $RandomClass doesn't exist) ",
);

# get general catalog object
my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');

# add test general catalog item
my $GeneralCatalogItemID = $GeneralCatalogObject->ItemAdd(
    Class   => 'ITSM::ConfigItem::Class',
    Name    => $RandomClass,
    ValidID => 1,
    Comment => 'Comment',
    UserID  => 1,
);

$GeneralCatalogObject->GeneralCatalogPreferencesSet(
    ItemID => $GeneralCatalogItemID,
    Key    => 'Permission',
    Value  => 5,
);

$Self->True(
    $GeneralCatalogItemID,
    "Test general catalog item is created - $GeneralCatalogItemID ",
);

# get ConfigItem object
my $ConfigItemObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');

# get 'Planned' deployment state IDs
my $PlannedDeplStateDataRef = $GeneralCatalogObject->ItemGet(
    Class => 'ITSM::ConfigItem::DeploymentState',
    Name  => 'Planned',
);
my $PlannedDeplStateID = $PlannedDeplStateDataRef->{ItemID};

my @ConfigItemNumbers;
my $ConfigItemID;

for ( 1 .. 10 ) {

    # create ConfigItem number
    my $ConfigItemNumber = $ConfigItemObject->ConfigItemNumberCreate(
        Type    => $Kernel::OM->Get('Kernel::Config')->Get('ITSMConfigItem::NumberGenerator'),
        ClassID => $GeneralCatalogItemID,
    );

    # add test ConfigItem
    $ConfigItemID = $ConfigItemObject->ConfigItemAdd(
        Number  => $ConfigItemNumber,
        ClassID => $GeneralCatalogItemID,
        UserID  => 1,
    );

    push @ConfigItemNumbers, $ConfigItemNumber;

    # add new versions for the last added in previous loop
    my $ConfigItemName = 'TestConfigItem' . $Helper->GetRandomID();

    COUNT:
    for my $Count ( 1 .. 50 ) {

        my $VersionID = $ConfigItemObject->VersionAdd(
            Name         => $ConfigItemName . '-' . $Count,
            DefinitionID => 1,
            DeplStateID  => $PlannedDeplStateID,
            InciStateID  => 1,
            UserID       => 1,
            ConfigItemID => $ConfigItemID,
        );

        $Self->True(
            $VersionID,
            "Version $Count for config item $ConfigItemID is created - $ConfigItemName",
        );
    }
}

# check command with class options ($RandomClass class) and deployment-state 'Planned'
$ExitCode = $CommandObject->Execute( '--class', $RandomClass, '--deployment-state', 'Planned' );

$Self->Is(
    $ExitCode,
    0,
    "Exit code: Options --class $RandomClass --deployment-state' Planned",
);

# check command with configitem-number options
$ExitCode = $CommandObject->Execute(
    '--configitem-number', $ConfigItemNumbers[0], '--configitem-number',
    $ConfigItemNumbers[1]
);

$Self->Is(
    $ExitCode,
    0,
    "Exit code: Options --configitem-number",
);

# check command with class options ($RandomClass class)
# three config Items of ten created in test were deleted with the previous commands
# with the next command other seven will be deleted
$ExitCode = $CommandObject->Execute( '--class', $RandomClass );

$Self->Is(
    $ExitCode,
    0,
    "Exit code: Option --class $RandomClass",
);

# cleanup is done by RestoreDatabase

1;
