# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# 
# Copyright (C) 2010 Michael Daum, http://michaeldaumconsulting.com
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

use Foswiki::Func ();
use Foswiki::Sandbox ();

use constant DEBUG => 0; # toggle me

our $switchBoard = {
  changeproperties => "Foswiki::Plugins::TopicInteractionPlugin::Action::ChangeProperties",
  delete => "Foswiki::Plugins::TopicInteractionPlugin::Action::DeleteAttachment",
  move => "Foswiki::Plugins::TopicInteractionPlugin::Action::MoveAttachment",
  upload => "Foswiki::Plugins::TopicInteractionPlugin::Action::UploadAttachment",
  createlink => "Foswiki::Plugins::TopicInteractionPlugin::Action::CreateLinks",
  createimagegallery => "Foswiki::Plugins::TopicInteractionPlugin::Action::CreateImageGallery",
  download => "Foswiki::Plugins::TopicInteractionPlugin::Action::DownloadAttachment",
  hide => "Foswiki::Plugins::TopicInteractionPlugin::Action::HideAttachment",
  unhide => "Foswiki::Plugins::TopicInteractionPlugin::Action::UnhideAttachment",
};

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
sub handleRest {
  my ($session, $subject, $verb, $response) = @_;

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
  my $web = $session->{webName};
  my $action = $params->{action} || 'upload';

  ($web, $topic) = Foswiki::Func::normalizeWebTopicName($web, $topic);
  unless (Foswiki::Func::topicExists($web, $topic)) {
    printJSONRPC($response, 101, "Topic $web.$topic does not exist", $id);
    return;
  }

  # check permissions
  unless (Foswiki::Func::checkAccessPermission(
    'CHANGE', Foswiki::Func::getWikiName(), undef, $topic, $web)) {
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

  # delegate action to the approriate handler
  my $actionHandler = $switchBoard->{$action};

  unless ($actionHandler) {
    printJSONRPC($response, -32601, "unknown action $action", $id);
    return;
  }

  writeDebug("actionHandler=$actionHandler");

  eval "use $actionHandler;";
  die "error reading action: $@" if $@;

  my $sub = $actionHandler."::handle";
  no strict 'refs';
  &$sub($response, $params);
  use strict 'refs';

  if ($action =~ /^(upload|delete|move|changeproperties)$/) {
    deleteAttachmentArchives($web, $topic);
  }

  return;
}

##############################################################################
# collects all params either sent via url or via post
sub getRequestParams {
  my $request = shift;

  my %params = ();

  foreach my $key ($request->param()) {
    my $val = $request->param($key);
    $params{$key} = urlDecode($val) if defined $val;
    writeDebug("param $key=$val") unless $key eq 'POSTDATA';
  }

  my $queryString = $ENV{QUERY_STRING};

  foreach my $item (split(/[&;]/, $queryString)) {
    if ($item =~ /^(.+?)=(.*)$/ && !defined($params{$1})) {
      $params{$1} = urlDecode($2);
      writeDebug("param $1=$params{$1}");
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
  my $downgradedValue = $session->UTF82SiteCharSet($value);
  $value = $downgradedValue if defined $downgradedValue;

  $value =~ s/^\s+//g;
  $value =~ s/\s+$//g;

  return $value;
}


##############################################################################
sub writeDebug {
  print STDERR "- TopicInteractionPlugin - $_[0]\n" if DEBUG;
}

##############################################################################
sub printJSONRPC {
  my ($response, $code, $text, $id) = @_;

  $response->header(
    -status  => $code?500:200,
    -type    => 'text/plain',
  );

  my $msg;
  $id = 'id' unless defined $id;

  if($code) {
    $msg = '{"jsonrpc" : "2.0", "error" : {"code": '.$code.', "message": "'.$text.'"}, "id" : "'.$id.'"}';
  } else {
    $msg = '{"jsonrpc" : "2.0", "result" : '.($text?'"'.$text.'"':'null').', "id" : "'.$id.'"}';
  }

  $response->print($msg);

  writeDebug("JSON-RPC: $msg");
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
    $zip = Foswiki::Sandbox::untaint($zip, \&Foswiki::Sandbox::validateAttachmentName);
    my $zipFile = $dir . '/' . $zip;
    writeDebug("deleting zip archive $zipFile");
    unlink $zipFile if -e $zipFile;
  }
}

1;
