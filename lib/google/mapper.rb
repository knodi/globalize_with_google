module Google
  
  module LocalizeCacheAccess
    def put_in_cache(key,language,translation)
      @cache["#{key}:#{language}:1"] = translation
    end
  end

  module Javascript
    def self.included(base)
      base.send :alias_method_chain, :javascript_include_tag, :google_scripts
    end
    def javascript_include_tag_with_google_scripts(*sources)
      javascript_include_tag_without_google_scripts(*sources) + 
      %Q{\n<script type="text/javascript" src="http://www.google.com/jsapi"></script>\n<script type="text/javascript">\ngoogle.load("language", "1");\n</script>\n}
    end
  end
  
  module MapperExtensions
    def self.included(base)
      base.send :alias_method_chain, :initialize, :google
    end
    def initialize_with_google(set)
      #we have to add ours FIRST, otherwise the final line of the regular routes.rb is usually a catchall that would intercept OUR route
      set.add_route('/cache_google_translation',{:controller => 'google/tricks', :action => 'cache_google_translation'})
      initialize_without_google(set)
    end
  end
  
  # A custom controller that we'll use for routing trickiness.
  class TricksController < ActionController::Base
    def cache_google_translation
      bound_vars = [params[:translation], params[:phrase]]
      ActiveRecord::Base.connection.execute("UPDATE globalize_translations SET built_in = 2, text = ? WHERE tr_key = ? AND language_id = #{Locale.language.id}".gsub('?'){ActiveRecord::Base.connection.quote(bound_vars.shift)})
      Locale.translator.put_in_cache(params[:phrase],Locale.language.iso_639_1,params[:translation])
      render :nothing => true
    end
  end
    
  module String
    def self.included(base)
      base.send :alias_method_chain, :translate, :google_caching
      base.send :alias_method, :t, :translate
    end
    def translate_with_google_caching(default = nil, arg = nil)
      local_base_language = defined?(BASE_LANGUAGE) ? BASE_LANGUAGE : 'en'

      #don't translate this if it's already written in the target language
      return self if Locale.language.iso_639_1 == local_base_language

      result = Locale.translate(self, '__translate__', arg)
      return result unless result ==  '__translate__' 

      return %Q{<span id="translation_#{self.object_id}">#{self}</span>
                <script type="text/javascript"> 
                  google.language.translate("#{self.gsub('"','\"')}",
                                            "#{local_base_language}",
                                            "#{Locale.language.iso_639_1}",
                                            function(result) { 
                                              if (!result.error) { 
                                                var target = document.getElementById('translation_#{self.object_id}'); 
                                                if (target != undefined) {
                                                  target.innerHTML = result.translation; 
                                                }
                                                new Ajax.Request('/cache_google_translation',{method: 'post', parameters: "phrase=#{self}&translation="+result.translation});
                                              } 
                                            }); 
                </script>}
    end
  end

end