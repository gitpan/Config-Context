
use strict;
use warnings;

use Test::More tests => 9;

use Config::Context;

my %Config_Text;

$Config_Text{'ConfigGeneral'} = <<'EOF';
    <Story Three Little Pigs>
        antagonist = Big Bad Wolf
        moral      = obey the protestant work ethic
    </Story>

    <Location /aesop>
        <Story Wolf in Sheep's Clothing>
            antagonist = Big Bad Wolf
            moral      = appearances are deceptive
        </Story>
    </Location>

    <Story Little Red Riding Hood>
        antagonist = Big Bad Wolf

        <Location /perrault>
            moral      = never talk to strangers
        </Location>

        <Location /grimm>
            moral      = talk to strangers and then chop them up
        </Location>
    </Story>
EOF

$Config_Text{'ConfigScoped'} = <<'EOF';
    Story 'Three Little Pigs' {
        antagonist = 'Big Bad Wolf'
        moral      = 'obey the protestant work ethic'
    }

    Location /aesop {
        Story = {
            "Wolf in Sheep's Clothing" = {
                antagonist = 'Big Bad Wolf'
                moral      = 'appearances are deceptive'
            }
        }
    }

    Story 'Little Red Riding Hood' {
        antagonist = 'Big Bad Wolf'

        Location = {
            /perrault = {
                moral      = 'never talk to strangers'
            }

            '/grimm' = {
                moral      = 'talk to strangers and then chop them up'
            }
        }
    }
EOF

$Config_Text{'XMLSimple'} = <<'EOF';
   <opt>
    <Story name="Three Little Pigs">
        <antagonist>Big Bad Wolf</antagonist>
        <moral>obey the protestant work ethic</moral>
    </Story>

    <Location name="/aesop">
        <Story name="Wolf in Sheep's Clothing">
            <antagonist>Big Bad Wolf</antagonist>
            <moral>appearances are deceptive</moral>
        </Story>
    </Location>

    <Story name="Little Red Riding Hood">
        <antagonist>Big Bad Wolf</antagonist>

        <Location name="/perrault">
            <moral>never talk to strangers</moral>
        </Location>

        <Location name="/grimm">
            <moral>talk to strangers and then chop them up</moral>
        </Location>
    </Story>
  </opt>
EOF

foreach my $driver (keys %Config_Text) {
    SKIP: {

        my $driver_module = 'Config::Context::' . $driver;
        eval "require $driver_module;";
        my $config_module = $driver_module->config_module;
        eval "require $config_module;";

        if ($@) {
            skip "$config_module not installed", 3;
        }

        my $conf = Config::Context->new(
            driver => $driver,
            string => $Config_Text{$driver},
            match_sections => [
                {
                    name         => 'Story',
                    match_type   => 'substring',
                    section_type => 'story',
                },
                {
                    name         => 'Location',
                    match_type   => 'path',
                    section_type => 'path',
                },
            ],
            nesting_depth => 2,
        );

        my $config = $conf->context(
                story => 'Wolf in Sheep\'s Clothing',
                path  => '/aesop/wolf-in-sheeps-clothing',
        );

        my $expected = {
            'antagonist' => 'Big Bad Wolf',
            'moral'      => 'appearances are deceptive'
        };

        ok(scalar(keys %$config) == 2,                        "$driver: keys");
        is($config->{'antagonist'}, 'Big Bad Wolf',           "$driver: antagonist");
        is($config->{'moral'}, 'appearances are deceptive',   "$driver: moral");
    }
}


