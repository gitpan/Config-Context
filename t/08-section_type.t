

use strict;
use warnings;

use Test::More 'no_plan';


use Config::Context;

my %Config_Text;

$Config_Text{'ConfigGeneral'} = <<'EOF';

    <Module Foo>
        val                   = 1
        sect                  = _Module_Foo
        Module_Foo           = 1
    </Module>

    <App Foo::Bar::>
        val                   = 2
        sect                  = _App_Foo_Bar_
        App_Foo_Bar_       = 1
    </App>

    <Module Foo::Bar::Baz>
        val                   = 3
        sect                  = _Module_Foo_Bar_Baz
        Module_Foo_Bar_Baz = 1
    </Module>

    <Path /foo>
        val                   = 4
        sect                  = _Path_foo
        Path_foo            = 1
    </Path>

    <Location /foo/bar>
        val                   = 5
        sect                  = _Location_foo_bar
        Location_foo_bar    = 1
    </Location>

    <LocationMatch zap>
        val                   = 6
        sect                  = _LocationMatch_zap
        LocationMatch_zap    = 1
    </LocationMatch>

    <FooMatch  a+>
        val                   = 7
        sect                  = _FooMatch_a_
        FooMatch_a_          = 1
    </FooMatch>

EOF

$Config_Text{'ConfigScoped'} = <<'EOF';

    Module Foo {
        val                   = 1
        sect                  = '_Module_Foo'
        'Module_Foo'         = 1
    }

    App 'Foo::Bar::' {
        val               = 2
        sect              = '_App_Foo_Bar_'
        'App_Foo_Bar_' = 1
    }

    Module 'Foo::Bar::Baz' {
        val                     = 3
        sect                    = '_Module_Foo_Bar_Baz'
        'Module_Foo_Bar_Baz' = 1
    }

    Path '/foo' {
        val          = 4
        sect         = '_Path_foo'
        'Path_foo' = 1
    }

    Location '/foo/bar' {
        val                  = 5
        sect                 = '_Location_foo_bar'
        'Location_foo_bar' = 1
    }

    LocationMatch 'zap'  {
        val                  = 6
        sect                 = '_LocationMatch_zap'
        'LocationMatch_zap' = 1
    }

    FooMatch  'a+'  {
        val            = 7
        sect           = '_FooMatch_a_'
        'FooMatch_a_' = 1
    }

EOF


$Config_Text{'XMLSimple'} = <<'EOF';

   <opt>
    <Module name="Foo">
        <val>1</val>
        <sect>_Module_Foo</sect>
        <Module_Foo>1</Module_Foo>
    </Module>

    <App name="Foo::Bar::">
        <val>2</val>
        <sect>_App_Foo_Bar_</sect>
        <App_Foo_Bar_>1</App_Foo_Bar_>
    </App>

    <Module name="Foo::Bar::Baz">
        <val>3</val>
        <sect>_Module_Foo_Bar_Baz</sect>
        <Module_Foo_Bar_Baz>1</Module_Foo_Bar_Baz>
    </Module>

    <Path name="/foo">
        <val>4</val>
        <sect>_Path_foo</sect>
        <Path_foo>1</Path_foo>
    </Path>

    <Location name="/foo/bar">
        <val>5</val>
        <sect>_Location_foo_bar</sect>
        <Location_foo_bar>1</Location_foo_bar>
    </Location>

    <LocationMatch name="zap">
        <val>6</val>
        <sect>_LocationMatch_zap</sect>
        <LocationMatch_zap>1</LocationMatch_zap>
    </LocationMatch>

    <FooMatch name="a+">
        <val>7</val>
        <sect>_FooMatch_a_</sect>
        <FooMatch_a_>1</FooMatch_a_>
    </FooMatch>
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
                    name           => 'App',
                    match_type     => 'hierarchy',
                    path_separator => '::',
                    section_type   => 'module',
                },
                {
                    name           => 'Module',
                    match_type     => 'path',
                    path_separator => '::',
                    section_type   => 'module',
                },
                {
                    name         => 'Path',
                    match_type   => 'path',
                    section_type => 'path',
                },
                {
                    name         => 'Location',
                    match_type   => 'path',
                    section_type => 'path',
                },
                {
                    name         => 'LocationMatch',
                    match_type   => 'substring',
                    section_type => 'path',
                },
                {
                    name         => 'FooMatch',
                    match_type   => 'regex',
                    section_type => 'foo',
                },
            ],
        );

        my %config;

        %config = $conf->context(
            module => 'Foo',
            path   => '/foo',
            foo    => 'xxx',
        );

        # <section> (chars): val
        # <Module Foo> (3): 1
        # <Path /foo>  (4): 4

        is($config{'val'},         4,             "$driver: [module=Foo,path=/foo,foo=xxx] val:         4");
        is($config{'sect'},        '_Path_foo',  "$driver: [module=Foo,path=/foo,foo=xxx] sect:        [Path]/foo");
        is($config{'Path_foo'},  1,             "$driver: [module=Foo,path=/foo,foo=xxx] [Path]/foo:  1");
        is($config{'Module_Foo'}, 1,             "$driver: [module=Foo,path=/foo,foo=xxx] [Module]Foo: 1");

        %config = $conf->context(
            module => 'Foo::Bar::Baz',
            path   => '/foo/bar/baz',
            foo    => 'apple',
        );
        # <section> (chars): val
        # <FooMatch a+>          (1): 7
        # <Module Foo>           (3): 1
        # <Path /foo>            (4): 4
        # <Location /foo/bar>    (8): 5
        # <App Foo_Bar_>       (10): 2
        # <Module Foo_Bar_Baz> (13): 3

        is($config{'val'},                    3,                       "$driver: _module=Foo::Bar::Baz,path=/foo/bar/baz,foo=apple] val:                 3");
        is($config{'sect'},                   '_Module_Foo_Bar_Baz', "$driver: [module=Foo::Bar::Baz,path=/foo/bar/baz,foo=apple] sect:                [Module]Foo::Bar::Baz");
        is($config{'FooMatch_a_'},           1,                       "$driver: [module=Foo::Bar::Baz,path=/foo/bar/baz,foo=apple] _FooMatch]a+:        1");
        is($config{'Module_Foo'},            1,                       "$driver: [module=Foo::Bar::Baz,path=/foo/bar/baz,foo=apple] [Module]Foo:         1");
        is($config{'Path_foo'},             1,                       "$driver: [module=Foo::Bar::Baz,path=/foo/bar/baz,foo=apple] [Path]/foo:          1");
        is($config{'Location_foo_bar'},     1,                       "$driver: [module=Foo::Bar::Baz,path=/foo/bar/baz,foo=apple] [Location]/foo/bar:  1");
        is($config{'App_Foo_Bar_'},        1,                       "$driver: [module=Foo::Bar::Baz,path=/foo/bar/baz,foo=apple] [App]Foo::Bar::      1");
        is($config{'Module_Foo_Bar_Baz'},  1,                       "$driver: [module=Foo::Bar::Baz,path=/foo/bar/baz,foo=apple] [App]Foo::Bar::Baz   1");
    }
}

