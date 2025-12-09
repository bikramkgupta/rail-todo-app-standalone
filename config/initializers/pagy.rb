# Pagy configuration
# See https://github.com/ddnexus/pagy/blob/master/lib/config/pagy.rb for all options

Pagy::DEFAULT[:items] = 6  # Items per page
Pagy::DEFAULT[:size]  = [1, 4, 4, 1]  # Page size: [*, 4, 4, *] = [prev, pages, next, last]
