# Monkey patches for rails to support our template engine.
# Hopefully these fixes will make it into rails or we find a
# better way to avoid this.
#
# TODO: Don't monkey patch rails

# See patch notes inline
class ::ActionView::Template

  # Patch, it's almost exaclty the same with a small tweak
  def handle_render_error(view, e) #:nodoc:
    if e.is_a?(::ActionView::Template::Error)
      e.sub_template_of(self)
      raise e
    else
      assigns  = view.respond_to?(:assigns) ? view.assigns : {}
      template = self

      # Here's the patch: if the javascript runtime throws an error
      # during compilation, we get to this handler but our view
      # doesn't have a lookup_context - thus throwing a very hard
      # to debug error in Template#refresh. To circumvent, ensure the
      # view responds to lookup_context before refreshing.
      if view.respond_to?(:lookup_context) and template.source.nil?
        template = refresh(view)
        template.encode!
      end
      raise ::ActionView::Template::Error.new(template, assigns, e)
    end
  end
end

if ::Rails.env == "development"
  # Monkey patch rails so it busts the server cache for templates
  # depending on the global_context_asset.
  #
  # Currently, the only way to force rails to recompile a server template is to
  # touch it. This is problematic because when the global_context_asset
  # changes we need to manually touch every template that uses the congtext
  # in some way.
  #
  # To ease development, make rails 'touch' and recompile hamlc templates
  # when the global context has changed.
  #
  # Do this ONLY in development.
  #
  # TODO: Don't monkey patch rails.
  class ::ActionView::Template
    def stale?
      return false unless ::Rails.env == "development"
      return false unless handler.respond_to?(:stale?)
      handler.stale?(updated_at)
    end

    alias_method :old_render, :render

    # by default, rails will only compile a template once
    # path render so it recompiles the template if 'stale'
    def render(view, locals, buffer=nil, &block)
      if @compiled and stale?
        now = Time.now
        File.utime(now, now, identifier) # touch file
        ::Rails.logger.info "Busted cache for #{identifier} by touching it"

        view = refresh(view)
        @source = view.source
        @compiled = false
      end
      old_render(view, locals, buffer, &block)
    end

  end
end
