# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008-2025 Michael Daum http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::RenderPlugin::Core;

use strict;
use warnings;

use Foswiki::Func();
use Foswiki::Plugins();
use Foswiki::Validation();
use Foswiki::Attrs ();
use JSON ();
use Error qw(:try);

use constant TRACE => 0; # toggle me

sub new {
  my $class = shift;
  my $session = shift || $Foswiki::Plugins::SESSION;

  my $this = bless({
    session => $session,
    allowedTags => $Foswiki::cfg{RenderPlugin}{TagHandler}{AllowedMacros} // '',
    cacheControl => $Foswiki::cfg{RenderPlugin}{CacheControl} // 28800,  # 8 hours in seconds
    @_
  }, $class);

  $this->{_doModifyHeaders} = 0;

  my %allowedTags = map { $_=> 1 } split(/\s*,\s*/, $this->{allowedTags});
  $this->{allowedTags} = \%allowedTags;

  return $this;
}

sub finish {
  my $this;

  undef $this->{_json};
}

sub writeDebug {
  print STDERR '- RenderPlugin - '.$_[0]."\n" if TRACE;
}

sub json {
  my $this = shift;

  unless (defined $this->{_json}) {
    $this->{_json} = JSON->new->allow_nonref(1);
  }

  return $this->{_json};
}

sub getZoneObject {
  my ($this, $zone, $meta) = @_;

  my @zone = ();
  my $excludeFromZone = $Foswiki::cfg{RenderPlugin}{ExcludeFromZone};

  foreach my $item (grep { $_->{text} } $this->getZoneItems($zone)) {
    if ($excludeFromZone && $item->{id} =~ /$excludeFromZone/g) {
      #print STDERR "excluding $item->{id}\n"; 
      next;
    }
    #print STDERR "id=$item->{id}\n"; 
    my @requires = map { $_->{id} } @{$item->{requires}};

    my $text = $meta->renderTML($meta->expandMacros($item->{text}));
    my $id = $item->{id};
    if ($Foswiki::Plugins::VERSION > 2.4 && $Foswiki::cfg{ObfuscateZoneIDs}) {
      $id =~ tr/N-ZA-Mn-za-m/A-Za-z/; # obfuscate ids
    }

    $text =~ s/\$id/$id/g;
    $text =~ s/\$zone/$zone/g;
    $text =~ s/^(\\n|\s+)//g;
    $text =~ s/(\\n|\s)+$//g;

    push @zone, {
      id => $id,
      text => $text,
      requires => \@requires,
    };
  }

  return \@zone;
}

sub getZoneItems {
  my ($this, $zone) = @_;

  my $session = $Foswiki::Plugins::SESSION;
  my $zonesHandler;

  if ($session->can("zones")) {
    # Foswiki > 2.0.3: zones are stored in a sub-component
    $zonesHandler = $session->zones();
  } else {
    # Foswiki <= 2.0.3: zones are stored in the session object
    $zonesHandler = $session;
  }

  # SMELL: violates encapsulation of Foswiki::Render::Zones
  my @zoneItems = values %{$zonesHandler->{_zones}{$zone}};
  my %visited = ();
  my @result = ();

  foreach my $item (@zoneItems) {
    $zonesHandler->_visitZoneID($item, \%visited, \@result);
  }

  return @result;
}

sub registerAllowedTag {
  my ($this, $name) = @_;

  return unless $name;

  $this->{allowedTags}{$name} = 1;
}

sub isAllowedTag {
  my ($this, $name) = @_;

  return 1 if $this->{allowedTags}{all};
  return 1 if $this->{allowedTags}{$name};
  return 0;
}

sub restTag {
  my ($this, $subject, $verb) = @_;

  #writeDebug("called restTag($subject, $verb)");

  # get params
  my $request = Foswiki::Func::getRequestObject();
  my $response = $this->{session}{response};
  my $theTag = $request->param('name') || 'INCLUDE';

  unless ($this->isAllowedTag($theTag)) {
    Foswiki::Func::writeWarning("tag REST handler called with forbidden macro");
    $response->header( -type => 'text/html', -status => '404' );
    return '404 Not Found';
  }

  my $theDefault = $request->param('param') || '';
  my $theRender = $request->param('render') || 0;
  $theRender = ($theRender =~ /^\s*(1|on|yes|true)\s*$/) ? 1:0;

  my $theTopic = $request->param('topic') || $this->{session}{topicName};
  my $theWeb = $request->param('web') || $this->{session}{webName};
  my ($web, $topic) = Foswiki::Func::normalizeWebTopicName($theWeb, $theTopic);
  $web = Foswiki::Sandbox::untaint($web, \&Foswiki::Sandbox::validateWebName);
  $topic = Foswiki::Sandbox::untaint($topic, \&Foswiki::Sandbox::validateTopicName);

  # construct parameters for tag
  my $params = $theDefault?'"'.$theDefault.'"':'';
  foreach my $key ($request->param()) {
    next if $key =~ /^(name|param|render|topic|XForms:Model)$/;
    my $value = $request->param($key);
    $value =~ s/"/\\"/g; # add them back in again
    $params .= ' '.$key.'="'.$value.'" ';
  }

  # create TML expression
  my $tml = '%'.$theTag;
  $tml .= '{'.$params.'}' if $params;
  $tml .= '%';

  #writeDebug("tml=$tml");

  # and render it
  my $result = $tml;
  $result = Foswiki::Func::expandCommonVariables($tml, $topic, $web) if $result =~ /%/;
  $result //= "";
  $result = Foswiki::Func::renderText($result, $web, $topic) if $theRender;

  #writeDebug("result=$result");

  my $contentType = $request->param("contenttype");
  my $fileName = $request->param("filename");
  if ($fileName) {
    $response->header(
      -type => $contentType || "text/html",
      -content_disposition => "attachment; filename=\"$fileName\"",
    );
  }

  $this->{_doModifyHeaders} = 1;
  $this->{session}->writeCompletePage($result, undef, $contentType);

  return;
}

sub restRender {
  my ($this, $subject, $verb) = @_;

  my $request = Foswiki::Func::getRequestObject();
  my $theText = $request->param('text') || '';

  return ' ' unless $theText; # must return at least on char as we get a
                              # premature end of script otherwise

  my $theTopic = $request->param('topic') || $this->{session}{topicName};
  my $theWeb = $request->param('web') || $this->{session}{webName};
  my ($web, $topic) = Foswiki::Func::normalizeWebTopicName($theWeb, $theTopic);
  $web = Foswiki::Sandbox::untaint($web, \&Foswiki::Sandbox::validateWebName);
  $topic = Foswiki::Sandbox::untaint($topic, \&Foswiki::Sandbox::validateTopicName);

  # expand and render
  my $result = $theText;
  $result = Foswiki::Func::expandCommonVariables($result, $topic, $web) if $result =~ /%/;
  $result //= "";
  $result = Foswiki::Func::renderText($result, $web, $topic);

  my $contentType = $request->param("contenttype");
  my $fileName = $request->param("filename");
  if ($fileName) {
    $this->{session}{response}->header(
      -type => $contentType || "text/html",
      -content_disposition => "attachment; filename=\"$fileName\"",
    );
  }

  $this->{_doModifyHeaders} = 1;
  $this->{session}->writeCompletePage($result, undef, $contentType);

  return;
}

sub restExpand {
  my ($this, $subject, $verb) = @_;

  # get params
  my $request = Foswiki::Func::getRequestObject();
  my $theText = $request->param('text') || '';

  return ' ' unless $theText; # must return at least on char as we get a
                              # premature end of script otherwise

  my $theTopic = $request->param('topic') || $this->{session}{topicName};
  my $theWeb = $request->param('web') || $this->{session}{webName};
  my ($web, $topic) = Foswiki::Func::normalizeWebTopicName($theWeb, $theTopic);
  $web = Foswiki::Sandbox::untaint($web, \&Foswiki::Sandbox::validateWebName);
  $topic = Foswiki::Sandbox::untaint($topic, \&Foswiki::Sandbox::validateTopicName);

  # expand
  my $result = $theText;
  $result = Foswiki::Func::expandCommonVariables($theText, $topic, $web) if $result =~ /%/;
  $result //= "";

  my $contentType = $request->param("contenttype");
  my $fileName = $request->param("filename");
  if ($fileName) {
    $this->{session}{response}->header(
      -type => $contentType || "text/html",
      -content_disposition => "attachment; filename=\"$fileName\"",
    );
  }

  $this->{_doModifyHeaders} = 1;
  $this->{session}->writeCompletePage($result, undef, $contentType);

  return;
}

sub restTemplate {
  my ($this, $subject, $verb) = @_;

  my $request = Foswiki::Func::getRequestObject();
  my $theTemplate = $request->param('name');
  throw Error::Simple("no template parameter") unless $theTemplate;

  my $theExpand = $request->param('expand');
  return throw Error::Simple("no expand parameter") unless $theExpand;

  my $theTopic = $request->param('topic') || $this->{session}{topicName};
  my $theWeb = $request->param('web') || $this->{session}{webName};
  my ($web, $topic) = Foswiki::Func::normalizeWebTopicName($theWeb, $theTopic);
  $web = Foswiki::Sandbox::untaint($web, \&Foswiki::Sandbox::validateWebName);
  $topic = Foswiki::Sandbox::untaint($topic, \&Foswiki::Sandbox::validateTopicName);

  Foswiki::Func::readTemplate($theTemplate);
  my $attrs = new Foswiki::Attrs($theExpand);

  my $tmpl = $this->{session}->templates->tmplP($attrs);

  # expand
  my $result = $tmpl;
  $result = Foswiki::Func::expandCommonVariables($result, $topic, $web) if $result =~ /%/;
  $result //= "";

  # render
  my $theRender = Foswiki::Func::isTrue(scalar $request->param('render'),  0);
  if ($theRender) {
    $result = Foswiki::Func::renderText($result, $web, $topic);
  }

  my $contentType = $request->param("contenttype") || "text/html";
  my $fileName = $request->param("filename");
  if ($fileName) {
    $this->{session}{response}->header(
      -type => $contentType,
      -content_disposition => "attachment; filename=\"$fileName\"",
    );
  }
  # overwrite cache control
  $this->{_doModifyHeaders} = 1;
  $this->{session}->writeCompletePage($result, undef, $contentType);

  return;
}

sub restJsonTemplate {
  my ($this, $subject, $verb) = @_;

  my $request = Foswiki::Func::getRequestObject();
  my $theTemplate = $request->param('name');
  return throw Error::Simple("no name parameter") unless $theTemplate;

  my $theExpand = $request->param('expand');
  return throw Error::Simple("no expand parameter") unless $theExpand;

  my $theTopic = $request->param('topic') || $this->{session}{topicName};
  my $theWeb = $request->param('web') || $this->{session}{webName};
  my ($web, $topic) = Foswiki::Func::normalizeWebTopicName($theWeb, $theTopic);
  $web = Foswiki::Sandbox::untaint($web, \&Foswiki::Sandbox::validateWebName);
  $topic = Foswiki::Sandbox::untaint($topic, \&Foswiki::Sandbox::validateTopicName);

  my ($meta) = Foswiki::Func::readTopic($web, $topic);

  Foswiki::Func::readTemplate($theTemplate);

  my $attrs = new Foswiki::Attrs($theExpand);

  my $tmpl = $this->{session}->templates->tmplP($attrs);
  $tmpl = Foswiki::Func::expandCommonVariables($tmpl, $topic, $web, $meta) if $tmpl =~ /%/;

  # expand
  my $result = {
    web => $web,
    topic => $topic,
    expand => $tmpl,
    zones => {},
  };

  # render
  my $theRender = Foswiki::Func::isTrue(scalar $request->param('render'),  0);
  if ($theRender) {
    $result->{expand} = Foswiki::Func::renderText($result->{expand}, $web, $topic);
  }
  $result->{expand} =~ s/^(\\n|\s+)//g;
  $result->{expand} =~ s/(\\n|\s)+$//g;
  $result->{expand} =~ s/\0NOTOC2\0//g;

  # inject validation
  my $cgis = $this->{session}->getCGISession();
  my $response = $this->{session}{response};

  if ($cgis && $Foswiki::cfg{Validation}{Method} ne 'none') {
    my $context = $request->url(-full => 1, -path => 1, -query => 1) . time();

    $result->{expand} =~ s/(<form[^>]*method=['"]POST['"][^>]*>)/Foswiki::Validation::addOnSubmit($1)/gei;
    $result->{expand} =~ s/(<form[^>]*method=['"]POST['"][^>]*>)/$1 . Foswiki::Validation::addValidationKey($cgis, $context, 1)/gei;

    $response->pushHeader('X-Foswiki-Validation', Foswiki::Validation::generateValidationKey($cgis, $context, 1));
  }

  # expand zones
  my $theZones = $request->param('zones') || '';
  foreach my $id (split(/\s*,\s*/, $theZones)) {
    $result->{zones}{$id} = $this->getZoneObject($id, $meta);
  }

  my $data = $this->json->pretty->encode($result);
  my $charSet = $Foswiki::cfg{Site}{CharSet}//'utf-8';

  $response->header(-'Content-Type' => "application/json; charset=$charSet");
  $this->{_doModifyHeaders} = 1;
  $this->{session}->writeCompletePage($data, undef, "application/json; charset=$charSet");

  return;
}

sub modifyHeaderHandler {
  my ($this, $headers, $query) = @_;

  return unless $this->{_doModifyHeaders};

  my $request = Foswiki::Func::getRequestObject();
  my $cacheControl = $request->param("cachecontrol") // $request->param("cache_expire") // $this->{cacheControl};
  $cacheControl = "max-age=$cacheControl" if $cacheControl =~ /^\d+$/;

  # set a better cache control
  $headers->{"Cache-Control"} = $cacheControl if $cacheControl;
}

1;
