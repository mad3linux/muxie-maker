# To change this template, choose Tools | Templates
# and open the template in the editor.
require "color"

class Project

  attr_accessor :name, :icon_color
  attr_reader :services

  def initialize name
    @name = name
    @services = []
    @icon_color = Color::GREEN
  end

  def add_service service
    if Service == service.class
      @services.push service.to_a
    elsif Array == service.class
      @services.push service
    end
  end

  def to_json
    JSON.pretty_generate({
      "name" => @name,
      "services" => @services,
      "icon_color" => @icon_color
    })
  end
end