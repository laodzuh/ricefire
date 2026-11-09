# The account's radio: songs an admin uploads, played as one station everyone hears in sync, or a YouTube live
# stream when there's nothing queued or the admin switches to it. See Radio::Station for how the sync works.
module Radio
  def self.table_name_prefix
    "radio_"
  end
end
