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

package Foswiki::Plugins::TopicInteractionPlugin::Action::DownloadAttachment;

use strict;
use warnings;

use Foswiki::Func ();
use Archive::Zip qw(:ERROR_CODES :CONSTANTS);
use Digest::MD5 ();
use URI ();
use Foswiki::Plugins::TopicInteractionPlugin::Action ();
our @ISA = ('Foswiki::Plugins::TopicInteractionPlugin::Action');
use constant DRY => 0; # toggle me

$Archive::Zip::UNICODE = 1;

sub handle {
  my ($this, $response) = @_;

  my $params = $this->prepareAction($response);
  return unless $params;

  my $web = $params->{web};
  my $topic = $params->{topic};
  my $id = $params->{id};

  my $pubDir  = $Foswiki::cfg{PubDir}.'/'.$web.'/'.$topic;
  my $archiveName = $this->getArchiveName($web, $topic, $params->{filenames});
  my $archivePath = $pubDir."/".$archiveName;
  my $archiveUrl = URI->new_abs($Foswiki::cfg{PubUrlPath}."/".$web."/".$topic."/".$archiveName, Foswiki::Func::getUrlHost()."/")->as_string;

  unless (-e $archivePath) {
    my $zip = Archive::Zip->new();
    foreach my $fileName (@{$params->{filenames}}) {
      next unless $fileName;

      unless (Foswiki::Func::attachmentExists($web, $topic, $fileName)) {
        $this->printJSONRPC($response, 104, "Attachment $fileName does not exist", $id);
        return;
      }

      $this->writeDebug("adding $fileName to zip");

      unless ($zip->addFile($pubDir."/".$fileName, $fileName)) {
        $this->printJSONRPC($response, 106, "Error while adding $fileName to the download archive", $id);
        return;
      }
    }

    $this->writeDebug("creating zip $archivePath");
    my $status = $zip->writeToFileNamed($archivePath);
    if ($status != AZ_OK) {
      $this->printJSONRPC($response, 107, "Error while creating archive", $id);
      return;
    }
  } else {
    $this->writeDebug("archive $archiveName already exists");
  }

  $this->printJSONRPC($response, 0, $archiveUrl, $id);
}

sub getArchiveName {
  my ($this, $web, $topic, $fileNames) = @_;

  $web =~ s/\//\./; # added for subweb support
  my ($meta, $text) = Foswiki::Func::readTopic( $web, $topic );
  my %attachments = map {$_->{name} => $_} $meta->find('FILEATTACHMENT');

  my $md5 = Digest::MD5->new();

  # loop over all files and generate an md5 checksum for this selection
  foreach my $fileName (@$fileNames) {
    my $attachment = $attachments{$fileName};
    unless ($attachment) {
      $this->writeDebug("warning $fileName not found in attachments hash");
      next;
    }
    $md5->add($fileName);
    $md5->add($attachment->{date});
    $md5->add($attachment->{size});
  }

  return "Attachments-$web-$topic-".$md5->hexdigest().".zip";
}

1;

