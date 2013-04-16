
class ::ActionView::Base

  # Rails keeps track of the context for a view
  # via an internal attribute called @_assigns.
  #
  # We'd like to serialize this context so that it's
  # available to hamlc templates. Unfortunately the
  # internal variable can be populated with circular
  # references making a simple call to #to_json
  # raise a stack level too deep exception.
  #
  # This method creates a hook to remove the bad keys
  # from the @_assigns hash and ensure a consistent
  # context for the template.
  #
  # By default, hamlc will call #to_json on this hash
  # and send it to the template.
  #
  #
  # TODO: find a better way to do this
  def view_assigns
    hash = @_assigns || {}

    # delete keys for methods added by rspec as the
    # template shouldn't use them and they can cause
    # circular reference errors
    internals = [
      :example,
      :fixture_cache,
      :fixture_connections,
      :loaded_fixtures,
      :_encapsulated_assigns
    ]

    internals.each { |key| hash.delete(key) }

    hash
  end
end
