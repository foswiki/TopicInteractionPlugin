# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# 
# Copyright (C) 2010-2016 Michael Daum, http://michaeldaumconsulting.com
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

package Foswiki::Plugins::TopicInteractionPlugin::Action::UploadAttachment;

use strict;
use warnings;

use Error qw( :try );
use Foswiki::Func ();
use Foswiki::Plugins::TopicInteractionPlugin::Action ();
our @ISA = ('Foswiki::Plugins::TopicInteractionPlugin::Action');

sub handle {
  my ($this, $response) = @_;
  
  my $params = $this->prepareAction($response, {
    requireFileName => 0
  });
  return unless $params;

  my $web = $params->{web};
  my $topic = $params->{topic};
  my $id = $params->{id};

  ($web, $topic) = Foswiki::Func::normalizeWebTopicName($web, $topic);

  my ($meta, undef) = Foswiki::Func::readTopic($web, $topic);

  # check permissions
  my $wikiName = Foswiki::Func::getWikiName();
  unless (Foswiki::Func::checkAccessPermission('CHANGE', $wikiName, undef, $topic, $web, $meta)) {
    $this->printJSONRPC($response, 102, "Access denied", $id);
    return;
  }

  my $maxSize = Foswiki::Func::getPreferencesValue('ATTACHFILESIZELIMIT');
  $maxSize = 0 unless ($maxSize =~ /([0-9]+)/);

  # read additional params
  my $request = Foswiki::Func::getCgiQuery();

  my $fileCreateLink = $params->{createlink} || '0';
  $fileCreateLink = $fileCreateLink eq 'on' ? 1:0;

  # loop thru all uploads
  my $uploads = $request->uploads();
  my @result = ();
  foreach my $fileName (keys %$uploads) {
    my $upload = $uploads->{$fileName};

    my $tmpFileName = $upload->tmpFileName;
    my $origName = $fileName;
    $fileName = $this->sanitizeAttachmentName($origName);

    unless ($fileName =~ /\./) {
      my $info = $upload->uploadInfo;
      my $suffix = $this->getSuffixOfMimeType($info->{"Content-Type"});
      $fileName .= ".".$suffix if $suffix;
    }

    my $stream = $upload->handle;
    my $fileSize;
    my $fileDate;
    if ($stream) {
      my @stats = stat $stream;
      $fileSize = $stats[7];
      $fileDate = $stats[9];
    }

    unless ($fileSize && $fileName) {
      $this->printJSONRPC($response, 1, "Zero-sized file upload of '$fileName'", $id);
      close($stream) if $stream;
      return; 
    }

    if ($maxSize && $fileSize > $maxSize * 1024) {
      $this->printJSONRPC($response, 1, "Oversized upload of '$fileName'", $id);
      close($stream) if $stream;
      return;
    }

    my $prevAttachment;
    my $fileComment = $params->{filecomment};
    unless (defined $fileComment) {
      # get prev comment as we override it otherwise
      $prevAttachment = $meta->get('FILEATTACHMENT', $fileName) || {};
      $fileComment = $prevAttachment->{comment} // '';
    }

    my $fileHide = $params->{hidefile};
    unless (defined $fileHide) {
      # get prev hide attr as we override it otherwise
      $prevAttachment = $meta->get('FILEATTACHMENT', $fileName) unless defined $prevAttachment;
      $fileHide = ($prevAttachment->{attr} && $prevAttachment->{attr} =~ /h/)?'on':'off';
    }
    $fileHide = $fileHide eq 'on' ? 1:0;

    $this->writeDebug("web=$web, topic=$topic, fileName=$fileName, origName=$origName, tmpFileName=$tmpFileName, fileComment=$fileComment, fileHide=$fileHide");

    my $error;
    try {
      $error = Foswiki::Func::saveAttachment(
        $web, $topic, $fileName, {
          dontlog     => !$Foswiki::cfg{Log}{upload},
          comment     => $fileComment,
          hide        => $fileHide,
          createlink  => $fileCreateLink,
          stream      => $stream,
          filesize    => $fileSize,
          filedate    => $fileDate,
          tmpFilename => $tmpFileName,
        });
    } catch Error::Simple with {
      $error = shift->{-text};
    };

    if ($error) {
      $this->printJSONRPC($response, 1, $error, $id);
      close($stream) if $stream;
      return;
    }

    close($stream) if $stream;
    push @result, {
      origName => $origName,
      fileName  => $fileName
    };
  }

  $this->printJSONRPC($response, 0, \@result, $id);
}

sub getSuffixOfMimeType {
  my ($this, $mimeType) = @_;

  my $suffix;

  unless ($this->{types}) {
    $this->{types} = Foswiki::Func::readFile($Foswiki::cfg{MimeTypesFileName});
  }

  if ($this->{types} =~ /^$mimeType\s+(\S+)\s*/im) {
    $suffix = $1;
    $this->writeDebug("getSuffixOfMimeType($mimeType) = $suffix");
  }

  return $suffix;
}


1;
