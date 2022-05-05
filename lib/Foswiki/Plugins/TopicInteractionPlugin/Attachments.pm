# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2005-2022 Michael Daum http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

package Foswiki::Plugins::TopicInteractionPlugin::Attachments;

use strict;
use warnings;

use POSIX ();
use Encode ();
use Error qw(:try);

#use Data::Dump qw(dump);
###############################################################################
sub new {
  my $class = shift;
  my $session = shift;

  $session ||= $Foswiki::Plugins::SESSION,

  my $this = bless({
      session => $session,
      @_,
    },
    $class
  );

  $this->{_attachmentInfo} = ();

  return $this;
}

###############################################################################
sub finish {
  my $this = shift;

  undef $this->{_attachmentInfo};
}

###############################################################################
sub handle {
  my ($this, $params, $theTopic, $theWeb, $obj, $compat) = @_;

  #writeDebug("called handleATTACHMENTS($theTopic, $theWeb)");
  #writeDebug("params=".$params->stringify());

  # get parameters
  my $thisTopic = $params->{_DEFAULT} || $params->{topic} || $this->{session}{topicName};
  my $thisWeb = $params->{web} || $this->{session}{webName};

  ($thisWeb, $thisTopic) = Foswiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);
  my $wikiName = Foswiki::Func::getWikiName();
  return "" unless Foswiki::Func::checkAccessPermission("VIEW", $wikiName, undef, $thisTopic, $thisWeb);

  my $theNames = $params->{names} || $params->{name} || '.*';
  my $theAttr = $params->{attr} || '.*';
  my $theAutoAttached = $params->{autoattached} || 2;
  $theAutoAttached = 0 if $theAutoAttached =~ /^(no|off)$/o;
  $theAutoAttached = 1 if $theAutoAttached =~ /^(yes|on)$/o;
  $theAutoAttached = 2 if $theAutoAttached eq 'undef';
  my $theMinDate = $params->{mindate};
  $theMinDate = Foswiki::Time::parseTime($theMinDate) if $theMinDate;
  my $theMaxDate = $params->{maxdate};
  $theMaxDate = Foswiki::Time::parseTime($theMaxDate) if $theMaxDate;
  my $theMinSize = $params->{minsize} || 0;
  my $theMaxSize = $params->{maxsize} || 0;
  my $theUser = $params->{user} || '.*';
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theFormat = $params->{format};
  my $theSeparator = $params->{separator};
  my $theSort = $params->{sort} || $params->{order} || 'name';
  my $theReverse = Foswiki::Func::isTrue($params->{reverse}, 0);
  my $theHideNull = Foswiki::Func::isTrue($params->{hidenull}, 0);
  my $theNullHeader = $params->{nullheader} || '';
  my $theNullFormat = $params->{nullformat} || '';
  my $theNullFooter = $params->{nullfooter} || '';
  my $theComment = $params->{comment} || '.*';
  my $theLimit = $params->{limit} || 0;
  my $theSkip = $params->{skip} || 0;
  #my $theWarn = Foswiki::Func::isTrue($params->{warn}, 1); 
  my $theInclude = $params->{include};
  my $theExclude = $params->{exclude};
  my $theCase = Foswiki::Func::isTrue($params->{casesensitive}, 1);
  my $theDateFormat = $params->{"dateformat"} || $Foswiki::cfg{DateManipPlugin}{DefaultDateTimeFormat} || '$day $mon $year - $hour:$min';

  $theLimit =~ s/[^\d]//g;
  $theLimit = 0 unless $theLimit;
  $theSkip =~ s/[^\d]//g;
  $theSkip = 0 unless $theSkip;

  $params->{limit} = $theLimit;
  $params->{skip} = $theSkip;

  $theFormat = '   * [[$url][$name]], $sizeK, <nobr>$date</nobr>, [[$wikiuser]], $comment'
    unless defined $theFormat;
  $theSeparator = $params->{sep} unless defined $theSeparator;
  $theSeparator = "\n" unless defined $theSeparator;

  my $theRev = $params->{rev} // $params->{revision};

  # sort attachments
  my ($meta) = Foswiki::Func::readTopic($thisWeb, $thisTopic, $theRev);
  my @attachments = map {$this->getAttachmentInfo($thisWeb, $thisTopic, $_) } $meta->find("FILEATTACHMENT");

  my $isNumeric;
  my %sorting = ();
  if ($theSort eq 'name') {
    %sorting = map {$_ => lc($_->{name})} @attachments;
    $isNumeric = 0;
  } elsif ($theSort eq 'type') {
    %sorting = map {$_ => lc($_->{extension}.$_->{name})} @attachments;
    $isNumeric = 0;
  } elsif ($theSort eq 'date') {
    %sorting = map {$_ => ($_->{date}||0)} @attachments;
    $isNumeric = 1;
  } elsif ($theSort eq 'size') {
    %sorting = map {$_ => ($_->{size}||0)} @attachments;
    $isNumeric = 1;
  } elsif ($theSort eq 'user') {
    %sorting = map {$_ => lc($_->{user}||'')} @attachments;
    $isNumeric = 0;
  } elsif ($theSort eq 'comment') {
    %sorting = map {$_ => lc($_->{comment}||'')} @attachments;
    $isNumeric = 0;
  } elsif ($theSort eq 'comment:name') {
    %sorting = map {$_ => lc($_->{comment}||$_->{name})} @attachments;
    $isNumeric = 0;
  } elsif ($theSort eq 'random') {
    %sorting = map {$_ => rand()} @attachments;
    $isNumeric = 1;
  } else {
    # apply predefined order
    my %attachments = map {$_->{name} => $_} @attachments;
    @attachments = ();

    $theSort =~ s/^\s+|\s+$//g;
    foreach my $item (split(/\s*,\s*/,$theSort)) {
      push @attachments, $attachments{$item} if defined $attachments{$item};
    }
  }

  if (defined $isNumeric) {
    if ($isNumeric) {
      @attachments = sort { $sorting{$a} <=> $sorting{$b} } @attachments;
    } else {
      @attachments = sort { $sorting{$a} cmp $sorting{$b} } @attachments;
    }
  }
  @attachments = reverse @attachments if $theReverse;

  # pre-compile regexes
  my $error;
  my $namePattern;
  my $attrPattern;
  my $includePattern;
  my $excludePattern;
  my $commentPattern;
  my $userPattern;
  
  try {
    $namePattern = qr/$theNames/;
    $attrPattern = qr/$theAttr/;
    $commentPattern = qr/$theComment/;
    $userPattern = qr/^($theUser)$/;
    $includePattern = $theCase?qr/$theInclude/:qr/$theInclude/i
      if defined $theInclude && $theInclude ne "";
    $excludePattern = $theCase?qr/$theExclude/:qr/$theExclude/i
      if defined $theExclude && $theExclude ne "";
  } catch Error::Simple with {
    $error = shift->stringify();
    $error =~ s/ at .*$//;
    $error = "<div class='foswikiAlert'><literal>$error</literal></div>";
  };
  return $error if $error;

  # collect result
  my @result;

  my $index = 0;
  my @selectedAttachments = ();
  foreach my $attachment (@attachments) {

    next unless $attachment->{name} =~ $namePattern;
    next unless $attachment->{attr} =~ $attrPattern;
    next if $theAutoAttached == 0 && $attachment->{autoattached} != 0;
    next if $theAutoAttached == 1 && $attachment->{autoattached} != 1;
    next if $theMinDate && $attachment->{date} < $theMinDate;
    next if $theMaxDate && $attachment->{date} > $theMaxDate;
    next unless $attachment->{user} =~ $userPattern;
    next if $theMinSize && $attachment->{size} < $theMinSize;
    next if $theMaxSize && $attachment->{size} > $theMaxSize;
    next unless $attachment->{comment} =~ $commentPattern;

    if ($includePattern) {
      next unless
        $attachment->{name} =~ $includePattern ||
        $attachment->{user} =~ $includePattern ||
        $attachment->{comment} =~ $includePattern ||
        $attachment->{attr} =~ $includePattern;
    }
    if ($excludePattern) {
      next if
        $attachment->{name} =~ $excludePattern ||
        $attachment->{user} =~ $excludePattern ||
        $attachment->{comment} =~ $excludePattern ||
        $attachment->{attr} =~ $excludePattern;
    }

    $index++;
    push @selectedAttachments, $attachment;
  }

  unless (@selectedAttachments) {
    return '' if $theHideNull;
    my $text = $theNullHeader.$theNullFormat.$theNullFooter;
    $text =~ s/\$web\b/$thisWeb/g;
    $text =~ s/\$topic\b/$thisTopic/g;
    return Foswiki::Func::decodeFormatTokens($text);
  }

  $params->{_count} = $index;
  return '' if $theHideNull && $index == 0;
  $theSkip = 0 if $theSkip > $index;
  $index = 0;
  my $webDAVFilter = $Foswiki::cfg{TopicInteractionPlugin}{WebDAVFilter};
  my $webDavUrl = $Foswiki::cfg{TopicInteractionPlugin}{WebDAVUrl} || 'webdav://$host/dav/$web/$topic_files/$attachment';
  my $host = Foswiki::Func::getUrlHost();
  $host =~ s/^https?:\/+//;
  $webDavUrl =~ s/\$host/$host/g;
  $webDavUrl =~ s/\$web/$thisWeb/g;
  $webDavUrl =~ s/\$topic/$thisTopic/g;

  my %extensions = ();
  foreach my $attachment (@selectedAttachments) {

    $index++;
    next if $theSkip >= $index;
    next if $theLimit && ($index-$theSkip) > $theLimit;
    $params->{_first} = $index unless defined $params->{_first};

    $extensions{$attachment->{extension}} = 1;

    my $iconUrl;
    my $icon;
    if (Foswiki::Func::getContext()->{MimeIconPluginEnabled}) {
      $iconUrl = '%MIMEICON{"' . $attachment->{name} . '" format="$url" size="16"}%';
      $icon = '%MIMEICON{"' . $attachment->{name} . '" size="16"}%';
    } else {
      $iconUrl = '%ICONURL{"' . $attachment->{name} . '" alt="else"}%';
      $icon = '%ICON{"' . $attachment->{name} . '" alt="else"}%';
    }

    my $encName = _urlEncode($attachment, 'name');
    my $id = _encodeName($attachment->{name});

    # actions
    my $thisWebDavUrl = $webDavUrl;
    $thisWebDavUrl =~ s/\$attachment/$encName/g;

    my $webDavAction = '<a rel="nofollow" href="' . $thisWebDavUrl . '" ' . 'title="%MAKETEXT{"Edit this attachment" args="<nop>' . $attachment->{name} . '"}%">' . '%MAKETEXT{"edit"}%</a>';

    my $propsUrl = '%SCRIPTURLPATH{"attach"}%/' . $thisWeb . '/' . $thisTopic . '?filename=' . $encName . '&revInfo=1';
    my $propsAction = '<a rel="nofollow" href="' . $propsUrl . '" ' . 'title="%MAKETEXT{"Manage properties of [_1]" args="<nop>' . $attachment->{name} . '"}%">' . '%MAKETEXT{"props"}%</a>';

    my $moveUrl = '%SCRIPTURLPATH{"rename"}%/' . $thisWeb . '/' . $thisTopic . '?attachment=' . $encName;
    my $moveAction = '<a rel="nofollow" href="' . $moveUrl . '" ' . 'title="%MAKETEXT{"Move or delete [_1]" args="<nop>' . $attachment->{name} . '"}%">' . '%MAKETEXT{"move"}%</a>';

    my $deleteUrl = '%SCRIPTURLPATH{"rename"}%/' . $thisWeb . '/' . $thisTopic . '?attachment=' . $encName . '&newweb=Trash';
    my $deleteAction = '<a rel="nofollow" href="' . $deleteUrl . '" ' . 'title="%MAKETEXT{"Delete [_1]" args="<nop>' . $attachment->{name} . '"}%">' . '%MAKETEXT{"delete"}%</a>';

    my $url = '%PUBURL%'."/$thisWeb/$thisTopic/$encName";
    my $urlPath = '%PUBURLPATH%'."/$thisWeb/$thisTopic/$encName";

    my $oldVersions = '';
    if ($theFormat =~ /\$oldversions/ && $attachment->{version} > 1) {
      my @oldVersions;
      for (my $i = $attachment->{version} - 1; $i > 0; $i--) {
        my ($date, $user, $rev, $comment) = Foswiki::Func::getRevisionInfo($thisWeb, $thisTopic, $i, $attachment->{name});
        $date = Foswiki::Func::formatTime($date, $theDateFormat);
        push @oldVersions, "$date;$user;$rev;$comment";
      }
      $oldVersions = join("\n", @oldVersions);
    }

    # use webdav urls for document types that are webdav-enabled; null them otherwise
    unless (Foswiki::Func::getContext()->{FilesysVirtualPluginEnabled} && defined($webDAVFilter) && $attachment->{name} =~ /\.($webDAVFilter)$/i) {
      $webDavAction = '';
      $thisWebDavUrl = '';
    }

    my $text = $theFormat;

    # compatibility with AttachmentListPlugin
    if ($compat) {
      $text =~ s/\$fileName/\$name/g;
      $text =~ s/\$fileSize/\$sizeH/g;
      $text =~ s/\$fileExtension/\$extension/g;
      $text =~ s/\$fileIcon/\$icon/g;
      $text =~ s/\$fileComment/\$comment/g;
      $text =~ s/\$fileUser/\$user/g;
      $text =~ s/\$fileDate/\$date/g;
      $text =~ s/\$fileUrl/\$url/g;
      $text =~ s/\$fileTopic/\$topic/g;
      $text =~ s/\$fileWeb/\$web/g;
      $text =~ s/\$hidden/$attachment->{hidden}?'hidden':''/ge;

# not supported
#    $text =~ s/\$viewfileUrl//g;
#    $text =~ s/\$fileActionUrl//g;
#    $text =~ s/\$imgTag//g;
#    $text =~ s/\$imgHeight//g;
#    $text =~ s/\$imgWidth//g;

    }

    # regular format tokens
    $text =~ s/\$movedfrom\b/$attachment->{movedfrom}/g;
    $text =~ s/\$movedfromweb\b/$attachment->{movedfromWeb}/g;
    $text =~ s/\$movedfromtopic\b/$attachment->{movedfromTopic}/g;
    $text =~ s/\$movedfromname\b/$attachment->{movedfromName}/g;
    $text =~ s/\$movedto\b/$attachment->{movedto}/g;
    $text =~ s/\$movedtoweb\b/$attachment->{movedtoWeb}/g;
    $text =~ s/\$movedtotopic\b/$attachment->{movedtoTopic}/g;
    $text =~ s/\$movedtoname\b/$attachment->{movedtoName}/g;
    $text =~ s/\$movedby\b/$attachment->{movedbyTopic}/g;
    $text =~ s/\$movedwhen\b/$attachment->{movedwhen}?Foswiki::Func::formatTime($attachment->{movedwhen}, $theDateFormat):'???'/ge;
    $text =~ s/\$movedwhen\(([^\)]+)\)/$attachment->{movedwhen}?Foswiki::Time::formatTime($attachment->{movedwhen}, $1):'???'/ge;
    $text =~ s/\$webdav\b/$webDavAction/g;
    $text =~ s/\$webdavUrl\b/$thisWebDavUrl/g;
    $text =~ s/\$propsUrl/$propsUrl/g;
    $text =~ s/\$props\b/$propsAction/g;
    $text =~ s/\$moveUrl\b/$moveUrl/g;
    $text =~ s/\$move\b/$moveAction/g;
    $text =~ s/\$delete\b/$deleteAction/g;
    $text =~ s/\$deleteUrl\b/$deleteUrl/g;
    $text =~ s/\$icon\b/$icon/g;
    $text =~ s/\$iconUrl\b/$iconUrl/g;
    $text =~ s/\$iconurl\b/$iconUrl/g;
    $text =~ s/\$attr\b/$attachment->{attr}/g;
    $text =~ s/\$autoattached\b/$attachment->{autoattached}/g;
    $text =~ s/\$comment\b/$attachment->{comment}/g;
    $text =~ s/\$date\(([^\)]+)\)/$attachment->{date}?Foswiki::Time::formatTime($attachment->{date}, $1):'???'/ge;
    $text =~ s/\$date\b/$attachment->{date}?Foswiki::Func::formatTime($attachment->{date}, $theDateFormat):'???'/ge;
    $text =~ s/\$hidden/$attachment->{hidden}?'1':'0'/ge;
    $text =~ s/\$index\b/$index/g;
    $text =~ s/\$name\b/$attachment->{name}/g;
    $text =~ s/\$extension/$attachment->{extension}/g;
    $text =~ s/\$id\b/$id/g;
    $text =~ s/\$path\b/$attachment->{path}/g;
    $text =~ s/\$size\b/$attachment->{size}/g;
    $text =~ s/\$sizeH\b/_humanizeBytes($attachment->{size})/ge;
    $text =~ s/\$sizeK\b/_humanizeBytes($attachment->{size}, 'KB')/ge;
    $text =~ s/\$sizeM\b/_humanizeBytes($attachment->{size}, 'MB')/ge;
    $text =~ s/\$sizeG\b/_humanizeBytes($attachment->{size}, 'GB')/ge;
    $text =~ s/\$sizeG\b/$attachment->{sizeG}/g;
    $text =~ s/\$url\b/$url/g;
    $text =~ s/\$urlpath\b/$urlPath/g;
    $text =~ s/\$user\b/$attachment->{userTopic}/g;
    $text =~ s/\$wikiuser\b/$attachment->{userWeb}.$attachment->{userTopic}/g;
    $text =~ s/\$version\b/$attachment->{version}/g;
    $text =~ s/\$oldversions\b/$oldVersions/g;
    $text =~ s/\$web\b/$thisWeb/g;
    $text =~ s/\$topic\b/$thisTopic/g;
    $text =~ s/\$encode\((.*?)\)/_urlEncode($attachment, $1)/ges;
    $text =~ s/\$exists\b/$attachment->{exists}/g;

    push @result, $text if $text;
  }
  $params->{_first} ||= 0;

  if ($compat) {
    $theHeader .= '$n';
    $theFooter = '$n'.$theFooter;
  }

  my $result = '';
  if ($params->{_count} == 0) {
    $result = $theHeader.$theNullFormat.$theFooter;
  } else {
    $result = $theHeader.join($theSeparator, @result).$theFooter;
  }

  if ($compat) {
    $result =~ s/\$fileCount/\$count/g;
    $result =~ s/\$fileExtensions/\$extensions/g;
  }

  my $extensions = join(", ", sort keys %extensions);

  $result =~ s/\$extensions/$extensions/g;
  $result =~ s/\$count\b/$params->{_count}/g;
  $result =~ s/\$count\b/$params->{_count}/g;
  $result =~ s/\$web\b/$thisWeb/g;
  $result =~ s/\$topic\b/$thisTopic/g;
  $result =~ s/\$pager/renderPager($thisWeb, $thisTopic, $params)/ge;

  return Foswiki::Func::decodeFormatTokens($result);
}

##############################################################################
sub getAttachmentInfo {
  my ($this, $web, $topic, $attachment) = @_;

  #print STDERR dump($attachment)."\n";
  my $key = $web . "::" . $topic . "::" . $attachment->{name};

  my $info = $this->{_attachmentInfo}{$key};

  return $info if defined $info;

  $info = {
    name => $attachment->{name},
    attr => ($attachment->{attr} || ''),
    autoattached => $attachment->{autoattached} || 0,
    date => $attachment->{date} || '',
    user => ($attachment->{user} || $attachment->{author} || 'UnknownUser'),
    size => $attachment->{size} || 0,
    comment => (defined $attachment->{comment}) ? $attachment->{comment} : '',
    path => ($attachment->{path} || ''),
    version => ($attachment->{version} || 1),
    exists => Foswiki::Func::attachmentExists($web, $topic, $attachment->{name})?1:0,
    movedfrom => $attachment->{movefrom} || '',
    movedto => $attachment->{movedto} || '',
    movedby => $attachment->{moveby} || '',
    movedwhen => $attachment->{movedwhen} || '',
  };

  $info->{movedfromWeb} = '';
  $info->{movedfromTopic} = '';
  $info->{movedfromName} = '';
  $info->{movedtoWeb} = '';
  $info->{movedtoTopic} = '';
  $info->{movedtoName} = '';

  my $origName = $attachment->{attachment} || $attachment->{name};

  if ($info->{movedfrom}) {
    if ($info->{movedfrom} =~ /^((.*)\.(.*?))\.(\Q$origName\E|\Q$info->{name}\E)$/) {
      $info->{movedfrom} = $1;
      $info->{movedfromWeb} = $2;
      $info->{movedfromTopic} = $3;
      $info->{movedfromName} = $4;
    } else {
      #print STDERR "failed to parse movedfrom '$info->{movedfrom}' of '$origName'\n";
    }
  }

  if ($info->{movedto}) {
    if ($info->{movedto} =~ /^((.*)\.(.*?))\.(\Q$origName\E|\Q$info->{name}\E)$/) {
      $info->{movedto} = $1;
      $info->{movedtoWeb} = $2;
      $info->{movedtoTopic} = $3;
      $info->{movedtoName} = $4;
    }
  }

  $info->{extension} = $info->{name} =~ /\.([^\.]*?)$/?lc($1):'';
  $info->{extension} =~ s/jpg/jpeg/;

  $info->{hidden} = $info->{attr} =~ /h/?1:0;

  if ($Foswiki::Plugins::VERSION >= 1.2) { # new Foswikis
    $info->{user} = Foswiki::Func::getWikiName($info->{user});
    $info->{movedby} = Foswiki::Func::getWikiName($info->{movedby}) if $info->{movedby};
  }

  ($info->{userWeb}, $info->{userTopic}) = Foswiki::Func::normalizeWebTopicName('', $info->{user});
  ($info->{movedbyWeb}, $info->{movedbyTopic}) = Foswiki::Func::normalizeWebTopicName('', $info->{movedby});

  $this->{_attachmentInfo}{$key} = $info;

  return $info;
}

our @BYTE_SUFFIX = ('B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB');
sub _humanizeBytes {
  my ($bytes, $max) = @_;

  $max ||= '';

  my $magnitude = 0;
  my $suffix;
  while ($magnitude < scalar(@BYTE_SUFFIX)) {
    $suffix = $BYTE_SUFFIX[$magnitude];
    last if $bytes < 1024;
    last if $max eq $suffix;
    $bytes /= 1024;
    $magnitude++;
  };

  my $result = sprintf("%.02f", $bytes);
  $result =~ s/\.00$//;
  $result .= ' '. $suffix;

  return $result;
}

##############################################################################
sub renderPager {
  my ($web, $topic, $params) = @_;

  # compute current and last page
  my $entriesPerPage = $params->{limit};
  $entriesPerPage = 10 unless defined $entriesPerPage;

  my $totalEntries = $params->{_count};
  my $lastPage = 0;
  my $currentPage = 0;
  my $firstEntry = $params->{_first};
  $lastPage = POSIX::ceil($totalEntries / $entriesPerPage)-1 if $entriesPerPage;
  $currentPage = POSIX::floor($firstEntry / $entriesPerPage) if $entriesPerPage;

  #print STDERR "entriesPerPage=$entriesPerPage, totalEntries=$totalEntries, currentPage=$currentPage, firstEntry=$firstEntry, lastPage=$lastPage\n";
  return '' unless $lastPage > 0;


  my $result = '';
  if ($currentPage > 0) {
    my $skip = ($currentPage - 1) * $entriesPerPage;
    $result .= "<a href='#skip$skip' class='foswikiAttachmentsPagerPrev' data-skip='$skip'>%MAKETEXT{\"Previous\"}%</a>";
  } else {
    $result .= "<span class='foswikiAttachmentsPagerPrev foswikiGrayText'>%MAKETEXT{\"Previous\"}%</span>";
  }

  if ($currentPage < $lastPage) {
    my $skip = ($currentPage + 1) * $entriesPerPage;
    $result .= "<a href='#skip$skip' class='foswikiAttachmentsPagerNext' data-skip='$skip'>%MAKETEXT{\"Next\"}%</a>";
  } else {
    $result .= "<span class='foswikiAttachmentsPagerNext foswikiGrayText'>%MAKETEXT{\"Next\"}%</span>";
  }

  my $startPage = $currentPage - 4;
  my $endPage = $currentPage + 4;
  if ($endPage >= $lastPage) {
    $startPage -= ($endPage-$lastPage+1);
    $endPage = $lastPage;
  }
  if ($startPage < 0) {
    $endPage -= $startPage;
    $startPage = 0;
  }
  $endPage = $lastPage if $endPage > $lastPage;

  if ($startPage > 0) {
    $result .= "<a href='#' data-skip='0'>1</a>";
  }

  if ($startPage > 1) {
    $result .= "<span class='foswikiAttachmentsPagerEllipsis'>&hellip;</span>";
  }

  my $count = 1;
  my $marker = '';
  for (my $i = $startPage; $i <= $endPage; $i++) {
    $marker = $i == $currentPage?'current':'';
    my $skip = $i * $entriesPerPage;
    $result .= "<a href='#skip$skip' class='$marker' data-skip='$skip'>".($i+1)."</a>";
    $count++;
  }

  if ($endPage < $lastPage-1) {
    $result .= "<span class='foswikiAttachmentsPagerEllipsis'>&hellip;</span>"
  }

  if ($endPage < $lastPage) {
    $marker = $currentPage == $lastPage?'current':'';
    my $skip = $lastPage * $entriesPerPage;
    $result .= "<a href='#skip$skip' class='$marker' data-skip='$skip'>".($lastPage+1)."</a>";
  }

  return $result;
}

##############################################################################
sub _urlEncode {
  my ($attachment, $property) = @_;

  my $text = defined($property)?$attachment->{$property}:$attachment;
  return $text unless $text;

  # below encoding must be uppercase hex values to be compatible with 
  # encodeURIComponent() in browsers

  # only encode reserverd characters
  $text =~ s/([\!#\$&'\(\)\*\+,\/:;=\?\@\[\]])/sprintf('%%%02X',ord($1))/ge; 

  return $text;
}

##############################################################################
sub _encodeName {
  my $text = shift;

  return $text unless $text;

  $text =~ s/[^0-9a-zA-Z_]/_/g; 

  return $text;
}

1;

