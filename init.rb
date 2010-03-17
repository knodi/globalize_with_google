require 'google/mapper'
require 'action_controller/routing'

#This one saves us from having double-entries in the globalize_translations table for every phrase that gets auto-translated
Globalize::DbViewTranslator.send :include, Google::LocalizeCacheAccess

ActionController::Routing::RouteSet::Mapper.send :include, Google::MapperExtensions

ActionView::Helpers::AssetTagHelper.send :include, Google::Javascript

String.send :include, Google::String