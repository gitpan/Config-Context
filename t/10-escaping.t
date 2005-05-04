

use strict;
use warnings;

use Test::More 'no_plan';


use Config::Context;

my %Config_Text;

$Config_Text{'ConfigGeneral'} = <<'EOF';
    Module = 0
    <Match \.pm$>
        Module = 1
    </Match>

EOF

$Config_Text{'ConfigScoped'} = <<'EOF';
    Module = 0
    Match '\.pm$' {
        Module = 1
    }

EOF

$Config_Text{'XMLSimple'} = <<'EOF';
   <opt>
    <Module>0</Module>
    <Match name="\.pm$">
        <Module>1</Module>
    </Match>
   </opt>

EOF

foreach my $driver (keys %Config_Text) {
    SKIP: {

        my $driver_module = 'Config::Context::' . $driver;
        eval "require $driver_module;";
        my @config_modules = $driver_module->config_modules;
        eval "require $_;" for @config_modules;

        if ($@) {
            skip "prereqs of $driver (".(join ', ', @config_modules).") not installed", 36;
        }

        my $conf = Config::Context->new(
            driver => $driver,
            string => $Config_Text{$driver},
            match_sections => [
                {
                    name         => 'Match',
                    match_type   => 'regex',
                    section_type => 'match',
                },
            ],

        );

        my %config;
        %config = $conf->context(
            match   => 'Simple.pm',
        );

        is($config{'Module'},      1, "$driver: [match: Simple.pm] Perl_Module:       1");

        %config = $conf->context(
            match   => 'Simplexpm',
        );
        ok(!$config{'Module'},        "$driver: [match: Simplexpm] Perl_Module:       0");
    }
}

