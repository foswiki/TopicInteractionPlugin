# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2010-2024 Michael Daum, http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::TopicInteractionPlugin::Action;

use strict;
use warnings;

use JSON ();
use Error qw(:try);
use Foswiki::Func ();
use Foswiki::Sandbox ();

use constant TRACE => 0; # toggle me

sub new {
  my $class = shift;

  my $this = bless({
      session => $Foswiki::Plugins::SESSION,
      @_
    },
    $class
  );

  return $this;
}

sub handle {
  my ($this, $response) = @_;

  die "not implemented";
}

sub prepareAction {
  my ($this, $response, $opts) = @_;

  $opts ||= {};
  $opts->{requireFileName} = 1 unless defined $opts->{requireFileName};

  $this->writeDebug("*** called handleRest()");

  # prevent any caching
  $response->header(
    -expires=>'-3d',
    -cache_control=>"no-store, no-cache, must-revalidate, post-check=0, pre-check=0",
    -pragma=>"no-cache"
  );

  my $request = Foswiki::Func::getRequestObject();
  my $params = $this->getRequestParams($request);
  my $id = $params->{id};

  unless ($id) {
    $this->printJSONRPC($response, 100, "No transaction id found", "???");
    return;
  }

  # sanitize and untaint id
  $id =~ s/[^\da-z]/_/g;
  $id =~ m/^(.*)$/; 
  $id = $1;

  if ( !Foswiki::Func::getContext()->{command_line} && $request && $request->method() && uc($request->method()) ne 'POST') {
    $this->printJSONRPC($response, -32600, "Method not Allowed", $id);
    return;
  }

  # read parameters 
  my $topic = $params->{topic} || $this->{session}{topicName};
  my $web = $this->{session}{webName};
  ($web, $topic) = Foswiki::Func::normalizeWebTopicName($web, $topic);

  my $fileName = $params->{name} || $params->{filename} || '';
  if ($opts->{requireFileName} && !$fileName) {
    $this->printJSONRPC($response, 103, "No filename", $id);
    return;
  }

  my $error;
  try {
    $this->validateWebName($web);
    $this->validateTopicName($topic);
    $this->validateAttachmentName($fileName) if $fileName;
  } catch Error with {
    $error = shift;
    $error =~ s/ at .*$//s;
  };

  if ($error) {
    $this->printJSONRPC($response, -32602, $error, $id);
    return;
  }

  #print STDERR "topic='$topic'\n";
  unless (Foswiki::Func::topicExists($web, $topic)) {
    $this->printJSONRPC($response, 101, "Topic $web.$topic does not exist", $id);
    return;
  }


  # check permissions
  my $wikiName = Foswiki::Func::getWikiName();
  $this->writeDebug("wikiName=$wikiName, web=$web, topic=$topic");
  unless (Foswiki::Func::checkAccessPermission(
    'VIEW', $wikiName, undef, $topic, $web)) {
    $this->printJSONRPC($response, 102, "Access denied", $id);
    return;
  }


  # playback to params to be used by delegates
  $params->{filename} = $fileName;
  $params->{topic} = $topic;
  $params->{web} = $web;
  $params->{id} = $id;

  $this->{params} = $params;

  return $params;
}

sub printJSONRPC {
  my ($this, $response, $code, $text, $id) = @_;

  $response->header(
    -status  => $code?500:200,
    -type    => 'text/plain', # SMELL: should be 'application/json' but some browsers open a filesave dialog on that one (woops)
  );

  $id = 'id' unless defined $id;

  my $message;
  
  if ($code) {
    $message = {
      jsonrpc => "2.0",
      error => {
        code => $code,
        message => $text,
        id => $id,
      }
    };
  } else {
    $message = {
      jsonrpc => "2.0",
      result => ($text?$text:'null'),
      id => $id,
    };
  }

  $message = JSON::to_json($message, {pretty=>1});
  $response->print($message);
}

##############################################################################
sub getFileNames {
  my ($this, $meta) = @_;

  my @fileNames;

  if ($this->{params}{filename} eq 'all') {
    @fileNames = map {$_->{name}} $meta->find("FILEATTACHMENT");
  }  else {
    @fileNames = @{$this->{params}{filenames}};
  }

  return @fileNames;
}

##############################################################################
# collects all params either sent via url or via post
sub getRequestParams {
  my ($this, $request) = @_;

  my %params = ();

  foreach my $key ($request->param()) {
    if ($key eq 'filename') { #SMELL: hard coded multi-val
      my @val = $request->multi_param($key);
      $params{$key} = $val[0];
      $params{$key."s"} = [@val];
    } else {
      my $val = $request->param($key);
      $params{$key} = $val if defined $val;
      $this->writeDebug("param $key=$val") unless $key eq 'POSTDATA';
    }
  }

#  my $queryString = $ENV{QUERY_STRING} || '';
#
#  foreach my $item (split(/[&;]/, $queryString)) {
#    if ($item =~ /^(.+?)=(.*)$/ && !defined($params{$1})) {
#      my $key = $1;
#      my $val = $2;
#      $params{$key} = urlDecode($val);
#      if ($key eq 'filename') { #SMELL: hard coded multi-val
#        $params{$key."s"} = [map {urlDecode($_)} split(/\s*,\s*/, $val)];
#      }
#      $this->writeDebug("param $key=$params{$key}");
#    }
#  }

  return \%params;
}

##############################################################################
sub setThumbnail {
  my ($this, $meta, $name, $value) = @_;

  $value = 1 unless defined $value;

  my $attachment = $meta->get("FILEATTACHMENT", $name);
  return unless $attachment; # does not exist

  my %attrs = map {$_ => 1} split(//, ($attachment->{attr} || ''));

  if ($value) {
    $attrs{t} = 1;
  } else {
    delete $attrs{t};
  }

  my $newAttr = join("", sort keys %attrs);

  return if $newAttr eq $attachment->{attr}; # already set

  # set new value
  $attachment->{attr} = $newAttr;
  $meta->putKeyed('FILEATTACHMENT', $attachment);

  # remove t attr from other attachments
  if ($value) {
    foreach my $otherAttachment ($meta->find("FILEATTACHMENT")) {
      next if $otherAttachment->{name} eq $name;
      if($otherAttachment->{attr} && $otherAttachment->{attr} =~ /t/) {
        %attrs = map {$_ => 1} split(//, $otherAttachment->{attr});
        delete $attrs{t};
        $otherAttachment->{attr} = join("", sort keys %attrs);
      }
    }
  }

  # save
  $meta->save();      
}

##############################################################################
# local version
sub sanitizeAttachmentName {
  my ($this, $fileName) = @_;

  my $origFileName = $fileName;

  my $filter =
       $Foswiki::cfg{AttachmentNameFilter}
    || $Foswiki::cfg{NameFilter}
    || '[^[:alnum:]\. _-]';

  $fileName =~ s{[\\/]+$}{};    # Get rid of trailing slash/backslash (unlikely)
  $fileName =~ s!^.*[\\/]!!;    # Get rid of leading directory components
  $fileName =~ s/$filter+//g;
  #$fileName =~ s/[{},\(\)]//g;    # some more

  $fileName =~ s/$Foswiki::cfg{UploadFilter}/$1\.txt/gi;

  return Foswiki::Sandbox::untaintUnchecked($fileName);
}

##############################################################################
sub validateAttachmentName {
  my ($this, $fileName) = @_;

  throw Error::Simple("invalid attachmnent name")
    unless Foswiki::Sandbox::untaint( $fileName, \&Foswiki::Sandbox::validateAttachmentName );
}

##############################################################################
sub validateWebName {
  my ($this, $web) = @_;

  throw Error::Simple("invalid web name")
    unless Foswiki::Sandbox::untaint($web, \&Foswiki::Sandbox::validateWebName);
}

##############################################################################
sub validateTopicName {
  my ($this, $topic) = @_;

  throw Error::Simple("invalid topic name")
    unless Foswiki::Sandbox::untaint($topic, \&Foswiki::Sandbox::validateTopicName);
}

##############################################################################
sub sanitizeString {
  my ($this, $str) = @_;

  return unless defined $str;
  my $orig = $str;

  $str =~ s/([[\x01-\x09\x0b\x0c\x0e-\x1f"%&\$'*<=>@\]_\|])/'&#'.ord($1).';'/ge;

  print STDERR "WARNING: string needed sanitize. possible attempt of an XSS attack in '$orig', stripped down to '$str'\n"
    unless $orig eq $str;

  return $str;
}

##############################################################################
sub writeDebug {
  my $this = shift;
  print STDERR "- TopicInteractionPlugin - $_[0]\n" if TRACE;
}

##############################################################################
sub writeError {
  my $this = shift;
  print STDERR "- TopicInteractionPlugin - $_[0]\n";
}


1;
