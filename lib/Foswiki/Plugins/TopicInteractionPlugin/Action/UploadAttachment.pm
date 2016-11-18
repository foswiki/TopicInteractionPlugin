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
use constant DRY => 0; # toggle me

sub handle {
  my ($this, $response) = @_;
  
  my $params = $this->prepareAction($response);
  return unless $params;

  my $web = $params->{web};
  my $topic = $params->{topic};
  my $id = $params->{id};

  # check permissions
  my $wikiName = Foswiki::Func::getWikiName();
  unless (Foswiki::Func::checkAccessPermission(
    'CHANGE', $wikiName, undef, $topic, $web)) {
    $this->printJSONRPC($response, 102, "Access denied", $id);
    return;
  }

  my $origName = $params->{filename};
  my $fileName = $this->sanitizeAttachmentName($origName);

  $this->writeDebug("'$origName' has been renamed to '$fileName'")
    unless $fileName eq $origName;
  
  # read additional params
  my $request = Foswiki::Func::getCgiQuery();
  my $nrChunks = $params->{chunks} || 0;
  my $contentType = $request->header('content-type') || '';
  my $isMultiPart = ($contentType =~ /multipart/)?1:0;
  my $chunk = $params->{chunk} || 0;

  my $fileCreateLink = $params->{createlink} || '0';
  $fileCreateLink = $fileCreateLink eq 'on' ? 1:0;

  my $fileHide = $params->{hidefile};
  $fileHide = 'off' unless defined $fileHide;
  $fileHide = $fileHide eq 'on' ? 1:0;

  my $fileComment = $params->{filecomment};
  $fileComment = '' unless defined $fileComment;

  $this->writeDebug("receiving file $fileName, chunk $chunk of $nrChunks, id=$id".($isMultiPart?' in multipart mode':' in normal mode'));

  # read application/octet-stream, can't use CGI.pm means
  my $tmpDir = Foswiki::Func::getWorkArea("TopicInteractionPlugin");
  my $tmpFileName = $tmpDir.'/'.$fileName.'_part_'.$id;
  my $data = '';

  # read data from request, either from a multipart of streamed request
  if ($isMultiPart) {
    my $stream = $request->upload('file');
    unless (defined $stream) {
      $this->printJSONRPC($response, 110, "Stream not found for '$fileName'", $id);
      return;
    }
    my $r;
    my $transfer;
    while ($r = sysread($stream, $transfer, 0x80000)) {
      if (!defined $r) {
        next if ($! == Errno::EINTR);
        $this->printJSONRPC($response, 1, "System read error: $!", $id);
        return;
      }
      $data .= $transfer;
    }
  } else {
    $data = $request->param("POSTDATA") || '';
  }

  if (-e $tmpFileName && $chunk <= $nrChunks) {
    $this->writeDebug("appending to $tmpFileName");
    $this->appendFile($tmpFileName, $data);
  } else {
    $this->writeDebug("saving to $tmpFileName");
    $this->saveFile($tmpFileName, $data);
  }

  # end of transaction
  if ($chunk+1 >= $nrChunks) {
    my $newFileName = $tmpFileName;
    $newFileName =~ s/_part_.*?$//;
    rename $tmpFileName, $newFileName 
      if $tmpFileName ne $newFileName;

    $this->writeDebug("finished uploading $newFileName");
    my ($meta, $text) = Foswiki::Func::readTopic($web, $topic);
    my $prevHide = '';
    my $prevComment = '';;
    my $prevAttachment = $meta->get('FILEATTACHMENT', $fileName);
    if($prevAttachment) {
      $prevComment = $prevAttachment->{comment} || '';
      $prevHide = ($prevAttachment->{attr} =~ /h/)?1:0;
      $this->writeDebug("prevComment=$prevComment, prevHide=$prevHide");
    } else {
      $this->writeDebug("no previous FILEATTACHMENT for $fileName");
    }

    my @stats = stat $newFileName;
    my $fileSize = $stats[7] || 0;
    my $fileDate = $stats[9] || 0;
    $fileComment = $prevComment unless $fileComment;
    $fileHide = $prevHide unless $fileHide;

    unless ($fileSize) {
      $this->printJSONRPC($response, 111, "Zero-sized file upload of '$fileName'", $id);
      return; 
    }

    # check content length
    my $maxSize = Foswiki::Func::getPreferencesValue('ATTACHFILESIZELIMIT');
    $maxSize = 0 unless ($maxSize =~ /([0-9]+)/o);
    $maxSize =~ s/[^\d]//g;

    $this->writeDebug("fileSize=$fileSize, maxSize=$maxSize, fileDate=$fileDate, fileComment=$fileComment, fileHide=$fileHide, fileCreateLink=$fileCreateLink");

    if ($maxSize && $fileSize > $maxSize * 1024) {
      $this->printJSONRPC($response, 109, "Oversized upload of '$fileName'", $id);
      return;
    }

    my $error;
    try {
      $this->writeDebug("attaching $fileName to $web.$topic");
      unless (DRY) {
        $error = Foswiki::Func::saveAttachment(
          $web, $topic, $fileName, {
            dontlog     => !$Foswiki::cfg{Log}{upload},
            comment     => $fileComment,
            hide        => $fileHide,
            createlink  => $fileCreateLink,
            file        => $newFileName,
            filesize    => $fileSize, # SMELL: which one is 
            size        => $fileSize, # SMELL: ... correct
            filedate    => $fileDate,
          });
      }
      $this->writeDebug("removing temp file $newFileName");
      unlink $newFileName if -e $newFileName;

      sleep(1); # sleep for a while to prevent a firing hurdle of events on save handlers in other extensions

    } catch Error::Simple with {
      $error = shift->{-text};
      $this->writeError("ERROR: $error");
    };

    if ($error) {
      $this->printJSONRPC($response, 1, $error, $id);
      return;
    }
  }

  $this->printJSONRPC($response, 0, {$origName => $fileName}, $id);
}

sub appendFile {
  my ($this, $name, $text) = @_;
  my $FILE;
  unless (open($FILE, '>>', $name)) {
    die "Can't append to $name - $!\n";
  }
  binmode($FILE);
  print $FILE $text;
  close($FILE);
}

sub saveFile {
  my ($this, $name, $text) = @_;
  my $FILE;
  unless (open($FILE, '>', $name)) {
    die "Can't create file $name - $!\n";
  }
  binmode($FILE);
  print $FILE $text;
  close($FILE);
}

1;
