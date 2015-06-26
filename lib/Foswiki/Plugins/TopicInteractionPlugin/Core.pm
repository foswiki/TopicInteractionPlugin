# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# 
# Copyright (C) 2010-2014 Michael Daum, http://michaeldaumconsulting.com
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

package Foswiki::Plugins::TopicInteractionPlugin::Core;

use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Sandbox ();
use JSON ();
use Encode ();

use constant TRACE => 0; # toggle me

# Error codes for json-rpc response
# -32601: unknown action
# -32600: method not allowed
# 0: ok
# 1: unknown error
# 100: no transaction id
# 101: topic does not exist
# 102: access denied
# 103: no filename
# 104: attachment does not exist
# 105: topic locked
# 106: error while addign file to download archiving
# 107: error while creating download archiving
# 108: won't copy attachment to itself
# 109: oversized upload
# 110: stream not found for file
# 111: zero-sized file upload

##############################################################################
sub restChangeProperties {
  my ($session, $subject, $verb, $response) = @_;
  
  my $params = prepareAction($session, $response);
  return unless $params;

  require Foswiki::Plugins::TopicInteractionPlugin::Action::ChangeProperties;
  Foswiki::Plugins::TopicInteractionPlugin::Action::ChangeProperties::handle($response, $params);
  deleteAttachmentArchives($params->{web}, $params->{topic});

  return;
}

##############################################################################
sub restDelete {
  my ($session, $subject, $verb, $response) = @_;
  
  my $params = prepareAction($session, $response);
  return unless $params;

  require Foswiki::Plugins::TopicInteractionPlugin::Action::DeleteAttachment;
  Foswiki::Plugins::TopicInteractionPlugin::Action::DeleteAttachment::handle($response, $params);
  deleteAttachmentArchives($params->{web}, $params->{topic});

  return;
}

##############################################################################
sub restMove {
  my ($session, $subject, $verb, $response) = @_;
  
  my $params = prepareAction($session, $response);
  return unless $params;

  require Foswiki::Plugins::TopicInteractionPlugin::Action::MoveAttachment;
  Foswiki::Plugins::TopicInteractionPlugin::Action::MoveAttachment::handle($response, $params);
  deleteAttachmentArchives($params->{web}, $params->{topic});

  return;
}

##############################################################################
sub restUpload {
  my ($session, $subject, $verb, $response) = @_;
  
  my $params = prepareAction($session, $response);
  return unless $params;

  require Foswiki::Plugins::TopicInteractionPlugin::Action::UploadAttachment;
  Foswiki::Plugins::TopicInteractionPlugin::Action::UploadAttachment::handle($response, $params);
  deleteAttachmentArchives($params->{web}, $params->{topic});

  return;
}

##############################################################################
sub restCreateLink {
  my ($session, $subject, $verb, $response) = @_;
  
  my $params = prepareAction($session, $response);
  return unless $params;

  require Foswiki::Plugins::TopicInteractionPlugin::Action::CreateLinks;
  Foswiki::Plugins::TopicInteractionPlugin::Action::CreateLinks::handle($response, $params);

  return;
}

##############################################################################
sub restCreateImageGallery {
  my ($session, $subject, $verb, $response) = @_;
  
  my $params = prepareAction($session, $response);
  return unless $params;

  require Foswiki::Plugins::TopicInteractionPlugin::Action::CreateImageGallery;
  Foswiki::Plugins::TopicInteractionPlugin::Action::CreateImageGallery::handle($response, $params);

  return;
}

##############################################################################
sub restDownload {
  my ($session, $subject, $verb, $response) = @_;
  
  my $params = prepareAction($session, $response);
  return unless $params;

  require Foswiki::Plugins::TopicInteractionPlugin::Action::DownloadAttachment;
  Foswiki::Plugins::TopicInteractionPlugin::Action::DownloadAttachment::handle($response, $params);

  return;
}

##############################################################################
sub restHide {
  my ($session, $subject, $verb, $response) = @_;
  
  my $params = prepareAction($session, $response);
  return unless $params;

  require Foswiki::Plugins::TopicInteractionPlugin::Action::HideAttachment;
  Foswiki::Plugins::TopicInteractionPlugin::Action::HideAttachment::handle($response, $params);

  return;
}

##############################################################################
sub restUnhide {
  my ($session, $subject, $verb, $response) = @_;
  
  my $params = prepareAction($session, $response);
  return unless $params;

  require Foswiki::Plugins::TopicInteractionPlugin::Action::UnhideAttachment;
  Foswiki::Plugins::TopicInteractionPlugin::Action::UnhideAttachment::handle($response, $params);

  return;
}

##############################################################################
sub prepareAction {
  my ($session, $response) = @_;

  writeDebug("*** called handleRest()");

  # prevent any caching
  $response->header(
    -expires=>'-3d',
    -cache_control=>"no-store, no-cache, must-revalidate, post-check=0, pre-check=0",
    -pragma=>"no-cache"
  );

  my $request = Foswiki::Func::getCgiQuery();
  my $params = getRequestParams($request);
  my $id = $params->{id};

  unless ($id) {
    printJSONRPC($response, 100, "No transaction id found", "???");
    return;
  }

  # sanitize and untaint id
  $id =~ s/[^\da-z]/_/g;
  $id =~ m/^(.*)$/; $id = 1;

  if ( $request && $request->method() && uc($request->method()) ne 'POST') {
    printJSONRPC($response, -32600, "Method not Allowed", $id);
    return;
  }

  # read parameters 
  my $topic = $params->{topic} || $session->{webTopic};
  $topic = Foswiki::decode_utf8($topic) if ( $Foswiki::UNICODE );
  my $web = $session->{webName};

  ($web, $topic) = Foswiki::Func::normalizeWebTopicName($web, $topic);
  #print STDERR "topic='$topic'\n";
  unless (Foswiki::Func::topicExists($web, $topic)) {
    printJSONRPC($response, 101, "Topic $web.$topic does not exist", $id);
    return;
  }

  # check permissions
  my $wikiName = Foswiki::Func::getWikiName();
  writeDebug("wikiName=$wikiName, web=$web, $topic=$topic");
  unless (Foswiki::Func::checkAccessPermission(
    'VIEW', $wikiName, undef, $topic, $web)) {
    printJSONRPC($response, 102, "Access denied", $id);
    return;
  }

  my $fileName = $params->{name} || $params->{filename} || '';
  unless ($fileName) {
    printJSONRPC($response, 103, "No filename", $id);
    return;
  }

  # playback to params to be used by delegates
  $params->{filename} = $fileName;
  $params->{topic} = $topic;
  $params->{web} = $web;
  $params->{id} = $id;

  return $params;
}

##############################################################################
# collects all params either sent via url or via post
sub getRequestParams {
  my $request = shift;

  my %params = ();

  foreach my $key ($request->param()) {
    if ($key eq 'filename') { #SMELL: hard coded multi-val
      my @val = $request->multi_param($key);
      $params{$key} = urlDecode($val[0]);
      $params{$key."s"} = [map {urlDecode($_)} @val];
    } else {
      my $val = $request->param($key);
      $params{$key} = urlDecode($val) if defined $val;
      writeDebug("param $key=$val") unless $key eq 'POSTDATA';
    }
  }

  my $queryString = $ENV{QUERY_STRING} || '';

  foreach my $item (split(/[&;]/, $queryString)) {
    if ($item =~ /^(.+?)=(.*)$/ && !defined($params{$1})) {
      my $key = $1;
      my $val = $2;
      $params{$key} = urlDecode($val);
      if ($key eq 'filename') { #SMELL: hard coded multi-val
        $params{$key."s"} = [map {urlDecode($_)} split(/\s*,\s*/, $val)];
      }
      writeDebug("param $key=$params{$key}");
    }
  }

  return \%params;
}

##############################################################################
# this one handles url params that are url-encoded and/or utf8 encoded
sub urlDecode {
  my $value = shift;

  $value =~ s/%([\da-f]{2})/chr(hex($1))/gei;
  my $session = $Foswiki::Plugins::SESSION;
  unless ($Foswiki::UNICODE) {
      my $downgradedValue = $session->UTF82SiteCharSet($value);
      $value = $downgradedValue if defined $downgradedValue;
  }
 
  $value =~ s/^\s+//g;
  $value =~ s/\s+$//g;

  return $value;
}


##############################################################################
sub writeDebug {
  print STDERR "- TopicInteractionPlugin - $_[0]\n" if TRACE;
}

##############################################################################
sub printJSONRPC {
  my ($response, $code, $text, $id) = @_;

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
  $response->body($message);
}

##############################################################################
sub deleteAttachmentArchives {
  my ($web, $topic) = @_;

  return unless $web && $topic;

  my $dir = "$Foswiki::cfg{PubDir}/$web/$topic";
  my $dh;

  opendir($dh, $dir) || return;
  my @zips = grep { /^Attachments-$web-$topic-.*zip$/ } readdir($dh);
  closedir($dh);

  unless (@zips) {
    #writeDebug("no archives to be cleaned up");
    return;
  }

  foreach my $zip (@zips) {
    if (defined(&Foswiki::Sandbox::validateAttachmentName)) {
      $zip = Foswiki::Sandbox::untaint($zip, \&Foswiki::Sandbox::validateAttachmentName);
    } else {
      $zip = Foswiki::Sandbox::normalizeFileName($zip);
    }
    my $zipFile = $dir . '/' . $zip;
    writeDebug("deleting zip archive $zipFile");
    unlink $zipFile if -e $zipFile;
  }
}

##############################################################################
sub setThumbnail {
  my ($meta, $name, $value) = @_;

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
        my %attrs = map {$_ => 1} split(//, $otherAttachment->{attr});
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
  my $fileName = shift;

  $fileName =~ s{[\\/]+$}{};    # Get rid of trailing slash/backslash (unlikely)
  $fileName =~ s!^.*[\\/]!!;    # Get rid of leading directory components
  $fileName =~ s/[\*?~^\$@%`"'&;|<>\[\]#\x00-\x1f\(\)]//g; # Get rid of a subset of Namefilter

  return Foswiki::Sandbox::untaintUnchecked($fileName);
}


1;
