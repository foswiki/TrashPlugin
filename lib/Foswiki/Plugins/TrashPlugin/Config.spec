# ---+ Extensions
# ---++ TrashPlugin
# This is the configuration used by the <b>TrashPlugin</b>.

# **BOOLEAN**
# Toggle debug output
$Foswiki::cfg{TrashPlugin}{Debug} = 0;

# **PERL**
$Foswiki::cfg{SwitchBoard}{cleanup_trash} = {
  package  => 'Foswiki::Plugins::TrashPlugin',
  function => 'cleanUp',
};

# **STRING**
# Time span before items in the trash will be deleted ultimately.
# Example values: <ul>
# <li>1M: delete items older than 1 month (default)</li>
# <li>6M: delete items older than 6 months</li>
# <li>1y: delete items older than 1 year</li>
# <li>30d: delete items older than 30 days</li>
# </ul>
$Foswiki::cfg{TrashPlugin}{Expire} = '1M';

# **REGEX EXPERT**
# A regular expression of topics that should not be deleted from trash.
$Foswiki::cfg{TrashPlugin}{ExcludeTopic} = '^(WebAtom|WebRss|WebSearch.*|WebChanges|WebStatistics|WebHome|WebNotify|WebTopicList|WebIndex|WebLeftBar|WebSideBar|WebPreferences|TrashAttachment|WebLeftBar.*)$';

1;
