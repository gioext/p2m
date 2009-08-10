port = request.port == 80 ? '' : ":" + request.port.to_s
base_url = request.scheme + '://' + request.host + port

xml.instruct!
xml.urlset(:xmlns => "http://www.sitemaps.org/schemas/sitemap/0.9",
           "xmlns:mobile".to_sym => "http://www.google.com/schemas/sitemap-mobile/1.0") do
  xml.url do
    xml.loc(base_url + '/')
    xml.priority("1.0")
    xml.mobile(:mobile)
  end
  @boards.each do |b|
    xml.url do
      xml.loc("#{base_url}/t/#{b[:id]}/1")
      xml.priority("0.8")
      xml.mobile(:mobile)
    end
  end
end
