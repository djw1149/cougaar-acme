# parsedate.rb: Written by Tadayoshi Funaba 2001, 2002
# $Id: parsedate.rb,v 1.1 2003-07-18 17:57:53 rich Exp $

require 'date/format'

module ParseDate

  def parsedate(str, comp=false)
    Date._parse(str, comp).
      indexes(:year, :mon, :mday, :hour, :min, :sec, :zone, :wday)
  end

  module_function :parsedate

end
