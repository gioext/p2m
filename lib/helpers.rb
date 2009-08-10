helpers do
  include Rack::Utils
  alias_method :h, :escape_html
  alias_method :u, :escape

  def content_for(key, &block)
    content_blocks[key.to_sym] << block
  end

  def yield_content(key)
    content_blocks[key.to_sym].map do |c|
      c.call
    end.join
  end

  def partial(template, options = {})
    options = options.merge({:layout => false})
    template = "_#{template.to_s}".to_sym
    _erb template, options
  end

  def atom_time(date)
    date.getgm.strftime("%Y-%m-%dT%H:%M:%SZ")
  end

  private
  def content_blocks
    @_content_blocks ||= Hash.new { |h, k| h[k] = [] }
  end
end
