# See bottom of file for license and copyright information
use strict;
use warnings;

package OembedPluginTests;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use strict;
use warnings;
use Test::MockModule;

my $foswiki;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

sub loadExtraConfig {
    my $this = shift; # the Test::Unit::TestCase object
    $this->SUPER::loadExtraConfig();

    # Configure the environment for the test
    $Foswiki::cfg{Plugins}{OembedPlugin}{Module} = 'Foswiki::Plugins::OembedPlugin';
    $Foswiki::cfg{Plugins}{OembedPlugin}{Enabled} = 1;
    $Foswiki::cfg{Plugins}{OembedPlugin}{ProviderList} = [{ url => 'http://www.example.com/provider/*', api => 'http://www.example.com/provider-api/oembed'},{ url => 'https://example.com/foo/bar', api => 'https://example.com/foo-api', name => 'Example provider'}];
    $Foswiki::cfg{Plugins}{OembedPlugin}{Maxwidth} = 720;
    $Foswiki::cfg{Plugins}{OembedPlugin}{Maxheight} = 721;
}

# Set up the test fixture
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
    $foswiki = $this->{session};
#    $Foswiki::Plugins::SESSION = $foswiki;
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
}

sub test_OEMBED {
    my $this = shift;

    my $actual;
    my $renderedActual;
    my $expected;
    my $renderedExpected;

    # mock Web::oEmbed to avoid api calls
    my $module = new Test::MockModule('Web::oEmbed');

    {
        #test provider registration - mock provider registration to check if it is called
        my @registered_providers;
        $module->mock('register_provider', sub { shift @_; push @registered_providers, @_; return 1;});

        $actual = '%OEMBED{"http://www.example.com"}%';
        $renderedActual =
        Foswiki::Func::expandCommonVariables( $actual, $this->{test_topic},
          $this->{test_web}, undef );
        $this->assert_deep_equals($Foswiki::cfg{Plugins}{OembedPlugin}{ProviderList}, \@registered_providers, 'configured providers are registered');
    }

    # Testcase: no url given
    {
        $actual = "%OEMBED%";
        $expected =  '%RED% No url given to be embedded %ENDCOLOR%';

        $renderedActual =
          Foswiki::Func::expandCommonVariables( $actual, $this->{test_topic},
            $this->{test_web}, undef );
        $renderedExpected =
          Foswiki::Func::expandCommonVariables( $expected, $this->{test_topic},
            $this->{test_web}, undef );

        $this->assert_str_equals( $renderedExpected, $renderedActual, "warning displayed if no url is given");
    }

    #Testcase: provider not registered
    {
        $actual = '%OEMBED{"http://www.example.com"}%';
        $expected = "http://www.example.com";
        $renderedActual =
          Foswiki::Func::expandCommonVariables( $actual, $this->{test_topic},
            $this->{test_web}, undef );
        $renderedExpected = Foswiki::Func::expandCommonVariables( $expected, $this->{test_topic},
            $this->{test_web}, undef );

        $this->assert_str_equals( $renderedExpected, $renderedActual, "link displayed if provider is not registered and _DEFAULT param used" );

        $actual = '%OEMBED{url="http://www.example.com"}%';
        $expected = "http://www.example.com";
        $renderedActual =
          Foswiki::Func::expandCommonVariables( $actual, $this->{test_topic},
            $this->{test_web}, undef );
        $renderedExpected = Foswiki::Func::expandCommonVariables( $expected, $this->{test_topic},
            $this->{test_web}, undef );

        $this->assert_str_equals( $renderedExpected, $renderedActual, "link displayed if provider is not registered and url param used" );
    }

    #url, maxwidth, maxheight are passed on correctly
    {
	my @embed_parameters;
	$module->mock('embed', sub { shift @_; @embed_parameters = @_; return Web::oEmbed::Response->new({type => 'video', html => 'html for video'}) });

	$actual = '%OEMBED{"http://www.example.com/xyz"}%';
	$renderedActual = Foswiki::Func::expandCommonVariables( $actual, $this->{test_topic}, $this->{test_web}, undef );
	$this->assert_str_equals( "http://www.example.com/xyz", $embed_parameters[0], 'url is passed on correctly if _DEFAULT param is used' );
	$this->assert_str_equals($Foswiki::cfg{Plugins}{OembedPlugin}{Maxwidth}, $embed_parameters[1]->{maxwidth}, 'maxwidth from LocalSite.cfg is passed on correctly' );
	$this->assert_str_equals($Foswiki::cfg{Plugins}{OembedPlugin}{Maxheight}, $embed_parameters[1]->{maxheight}, 'maxheight from LocalSite.cfg is passed on correctly' );

	$actual = '%OEMBED{url="http://www.example.com/abc" maxwidth="730" maxheight="731"}%';
	$renderedActual = Foswiki::Func::expandCommonVariables( $actual, $this->{test_topic}, $this->{test_web}, undef );
	$this->assert_str_equals( "http://www.example.com/abc", $embed_parameters[0], 'url is passed on correctly if url param is used' );
	$this->assert_str_equals('730', $embed_parameters[1]->{maxwidth}, 'maxwidth parameter is passed on correctly' );
	$this->assert_str_equals('731', $embed_parameters[1]->{maxheight}, 'maxheight parameter is passed on correctly' );
    }

    #registered provider returns type 'video'
    {
	$module->mock('embed', sub { return Web::oEmbed::Response->new({type => 'video', html => 'html for video'}) });

	$actual = '%OEMBED{"http://www.example.com"}%';
	$expected = "html for video";
	$renderedActual = Foswiki::Func::expandCommonVariables( $actual, $this->{test_topic}, $this->{test_web}, undef );
	$renderedExpected = $expected;

	$this->assert_str_equals( $renderedExpected, $renderedActual, "response type video embedded" );
    }

    #registered provider returns type 'rich'
    {
	$module->mock('embed', sub { return Web::oEmbed::Response->new({type => 'video', html => 'html for rich'}) });

	$actual = '%OEMBED{"http://www.example.com"}%';
	$expected = "html for rich";
	$renderedActual = Foswiki::Func::expandCommonVariables( $actual, $this->{test_topic}, $this->{test_web}, undef );
	$renderedExpected = $expected;

	$this->assert_str_equals( $renderedExpected, $renderedActual, "response type rich embedded" );
    }

    #registered provider returns type 'link'
    {
	$module->mock('embed', sub { return Web::oEmbed::Response->new({type => 'link', title => 'title for link', url => 'http://www.example.com'}) });

	$actual = '%OEMBED{"http://www.example.com"}%';
	$expected = '<a href="http://www.example.com">title for link</a>';
	$renderedActual = Foswiki::Func::expandCommonVariables( $actual, $this->{test_topic}, $this->{test_web}, undef );
	$renderedExpected = $expected;

	$this->assert_str_equals( $renderedExpected, $renderedActual, "response type link embedded" );
    }

    #registered provider returns type 'photo' including a thumbnail
    {
	$module->mock('embed', sub { return Web::oEmbed::Response->new({type => 'photo', thumbnail_url => 'http://www.example.com/thumbnail', thumbnail_width => 30, thumbnail_height => 50, url => 'http://www.example.com/photo'}) });

	$actual = '%OEMBED{"http://www.example.com"}%';
	$expected = '<a href="http://www.example.com/photo"><img src="http://www.example.com/thumbnail" width="30" height="50"></a>';
	$renderedActual = Foswiki::Func::expandCommonVariables( $actual, $this->{test_topic}, $this->{test_web}, undef );

	$this->assert_matches( '<a href="http://www.example.com/photo">', $renderedActual, "response typ photo embedded - links correctly" );
	$this->assert_matches( 'src="http://www.example.com/thumbnail"', $renderedActual,  "response typ photo embedded - thumbnail displayed" );
	$this->assert_matches( 'height="50"', $renderedActual, "response typ photo embedded - correct thumbnail height" );
	$this->assert_matches( 'width="30"', $renderedActual, "response typ photo embedded - correct thumbnail width" );
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Author: KerstinPuschke

Copyright (C) 2008-2011 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
