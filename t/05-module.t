

# This test just
# copies 04-path, with the following changes:
#  * replace Module with Path
#  * replace App with Location
#  * replace txt with pm
#  * specify a PathSeparator of '::'

use strict;
use warnings;

use Test::More 'no_plan';


use Config::Context;

my %Config_Text;

$Config_Text{'ConfigGeneral'} = <<EOF;

    <Module Foo>
        val  = 1
        sect = foo
        foo  = 1
    </Module>

    <App Foo::Bar>
        val    = 2
        sect   = foobar
        foobar = 1
    </App>

    <Module Foo::Bar::Baz>
        val       = 3
        sect      = foobarbaz
        foobarbaz = 1
    </Module>

EOF

$Config_Text{'ConfigScoped'} = <<EOF;

    Module Foo {
        val  = 1
        sect = foo
        foo  = 1
    }

    App Foo::Bar {
        val    = 2
        sect   = foobar
        foobar = 1
    }

    Module Foo::Bar::Baz {
        val       = 3
        sect      = foobarbaz
        foobarbaz = 1
    }

EOF

$Config_Text{'XMLSimple'} = <<EOF;

    <opt>
     <Module name="Foo">
         <val>1</val>
         <sect>foo</sect>
         <foo>1</foo>
     </Module>

     <App name="Foo::Bar">
         <val>2</val>
         <sect>foobar</sect>
         <foobar>1</foobar>
     </App>

     <Module name="Foo::Bar::Baz">
         <val>3</val>
         <sect>foobarbaz</sect>
         <foobarbaz>1</foobarbaz>
     </Module>
    </opt>

EOF


foreach my $driver (keys %Config_Text) {
    SKIP: {

        my $driver_module = 'Config::Context::' . $driver;
        eval "require $driver_module;";
        my $config_module = $driver_module->config_module;
        eval "require $config_module;";

        if ($@) {
            skip "$config_module not installed", 30;
        }

        my $conf = Config::Context->new(
            driver => $driver,
            string => $Config_Text{$driver},
            match_sections => [
                {
                    name           => 'App',
                    match_type     => 'hierarchy',
                    path_separator => '::',
                    merge_priority => 1,
                },
                {
                    name           => 'Module',
                    match_type     => 'path',
                    path_separator => '::',
                    merge_priority => 2,
                },
            ],
        );

        my %config;

        %config = $conf->context('Foo');
        # Foo (1)
        is($config{'sect'},       'foo',  "$driver: [Foo] sect:      foo");
        is($config{'val'},        1,      "$driver: [Foo] val:       1");
        is($config{'foo'},        1,      "$driver: [Foo] foo:       1");
        ok(!exists $config{'foobar'},     "$driver: [Foo] foobar:    not present");
        ok(!exists $config{'foobarbaz'},  "$driver: [Foo] foobarbaz: not present");

        %config = $conf->context('Foo::');
        # Foo (1)
        is($config{'sect'},       'foo',  "$driver: [Foo::] sect:      foo");
        is($config{'val'},        1,      "$driver: [Foo::] val:       1");
        is($config{'foo'},        1,      "$driver: [Foo::] foo:       1");
        ok(!exists $config{'foobar'},     "$driver: [Foo::] foobar:    not present");
        ok(!exists $config{'foobarbaz'},  "$driver: [Foo::] foobarbaz: not present");

        %config = $conf->context('Foo::Bar');
        # Foo::Bar (2), Foo (1)
        is($config{'sect'},       'foo',  "$driver: [Foo::Bar] sect:      foo");
        is($config{'val'},        1,      "$driver: [Foo::Bar] val:       1");
        is($config{'foo'},        1,      "$driver: [Foo::Bar] foo:       1");
        is($config{'foobar'},     1,      "$driver: [Foo::Bar] foobar:    1");
        ok(!exists $config{'foobarbaz'},  "$driver: [Foo::Bar] foobarbaz: not present");

        %config = $conf->context('Foo::Bar.txt');
        # Foo (1)
        is($config{'sect'},       'foo',  "$driver: [Foo::Bar.txt] sect:      foo");
        is($config{'val'},        1,      "$driver: [Foo::Bar.txt] val:       1");
        is($config{'foo'},        1,      "$driver: [Foo::Bar.txt] foo:       1");
        ok(!exists $config{'foobar'},     "$driver: [Foo::Bar.txt] foobar:    not present");
        ok(!exists $config{'foobarbaz'},  "$driver: [Foo::Bar.txt] foobarbaz: not present");

        %config = $conf->context('Foo::Bar::Baz::Boom.pm');
        # Foo::bar     (2)
        # Foo         (1)
        # Foo::bar/baz (3)
        is($config{'sect'},       'foobarbaz',  "$driver: [Foo::Bar::Baz::Boom.pm] sect:      foobarbaz");
        is($config{'val'},        3,            "$driver: [Foo::Bar::Baz::Boom.pm] val:       3");
        is($config{'foo'},        1,            "$driver: [Foo::Bar::Baz::Boom.pm] foo:       1");
        is($config{'foobar'},     1,            "$driver: [Foo::Bar::Baz::Boom.pm] foobar:    1");
        is($config{'foobarbaz'},  1,            "$driver: [Foo::Bar::Baz::Boom.pm] foobarbaz: 1");


        # No matches
        %config = $conf->context('Foo.pm');
        ok (!keys %config, "$driver: Foo.pm: no match");

        %config = $conf->context('foo');
        ok (!keys %config, "$driver: foo: no match");

        %config = $conf->context('foo.pm');
        ok (!keys %config, "$driver: foo.pm: no match");

        %config = $conf->context('Food');
        ok (!keys %config, "$driver: Food: no match");

        %config = $conf->context('Food::Bar.pm');
        ok (!keys %config, "$driver: Food::Bar.pm: no match");
    }
}

