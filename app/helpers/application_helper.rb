module ApplicationHelper
  # Include Pagy frontend helpers for pagination UI
  include Pagy::Frontend

  # Render Markdown with kramdown and sanitize the output for safe display
  def render_markdown(text)
    return "No description provided." if text.blank?

    html = Kramdown::Document.new(text, input: "GFM").to_html
    sanitize(
      html,
      tags: %w[p br strong em a code pre ul ol li blockquote h1 h2 h3 h4 h5 h6 del hr],
      attributes: %w[href title rel target]
    )
  rescue StandardError => e
    Rails.logger.warn("Markdown render failed: #{e.message}")
    text
  end
end
