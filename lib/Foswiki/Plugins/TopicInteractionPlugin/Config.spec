# ---+ Extensions
# ---++ TopicInteractionPlugin

# **REGEX EXPERT**
# Specify a regular expression matching fileextensions to be webdav enabled in the attachments list of a topic. 
# By default this is undefined. Use 
# <code>qr/((xlt|xls|ppt|pps|pot|doc|dot)(x|m)?)|odc|odb|odf|odg|otg|odi|odp|otp|ods|ots|odt|odm|ott|oth|mpp/</code>
# as a good coverage of the most common office document extensions.
$Foswiki::cfg{TopicInteractionPlugin}{WebDAVFilter} = '((xlt|xls|csv|ppt|pps|pot|doc|dot)(x|m)?)|odc|odb|odf|odg|otg|odi|odp|otp|ods|ots|odt|odm|ott|oth|mpp|rtf|txt|vsd';

# **SELECT ,libreoffice, openoffice, msoffice CHECK="undefok emptyok"**
# Set the default office suite that will be used to open webdav-enabled links. This setting can be customized
# further by setting the preference <code>WEBDAV_OFFICE_SUITE</code> in the SitePreferences or the user preferences.
$Foswiki::cfg{TopicInteractionPlugin}{DefaultOfficeSuite} = 'msoffice';

# **STRING**
# Defines the uri pattern for webdav links. Empty this in case you don't use webdav enabled urls.
$Foswiki::cfg{TopicInteractionPlugin}{WebDAVUrl} = 'webdav://$host/dav/$web/$topic_files/$attachment';

1;
