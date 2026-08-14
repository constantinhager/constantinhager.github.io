#!/usr/bin/env ruby
#
# Historically this site's post permalink toggled between `/:title/` and the
# current `/posts/:title/`, so search engines still have the old `/:title/`
# URLs indexed. Generate a `redirect_from` entry for each post so
# jekyll-redirect-from can emit a redirect page at the legacy URL.

Jekyll::Hooks.register :site, :post_read do |site|
  site.posts.docs.each do |post|
    legacy_url = post.url.sub(%r{\A/posts/}, "/")

    if legacy_url != post.url
      post.data["redirect_from"] ||= legacy_url
    end
  end
end
