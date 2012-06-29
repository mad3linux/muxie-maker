require "json"

class Service

  attr_accessor :type, :uid, :desc, :enable

  def initialize
    @enable = true
  end

  def to_a
    [@type, @uid, @desc, @enable]
  end

  module Type
    Blogger = 1
    Twitter = 2
    Facebook = 3
    Wordpress = 4
    Identica = 5
    Custom = 99

    def self.to_a
      [Blogger, Twitter, Facebook, Wordpress, Identica, Custom]
    end

    def self.to_s
      "[#{Blogger}] Blogger      [#{Twitter}] Twitter    [#{Facebook}] Facebook\n" +
      "[#{Wordpress}] Wordpress    [#{Identica}] Identica   [#{Custom}] Custom"
    end
  end
end
