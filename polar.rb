#!/usr/bin/env ruby
require 'pry'
require 'erb'
require 'nenv'

CHART_WIDTH  = 800
CHART_HEIGHT = 600
MAIN_TITLE = 'Overview'

def read_data(filename)
  lines = File.readlines(filename).map { |l| l.split(',') }
  data  = {}

  lines.each do |line|
    cat                   = data.fetch(line[0].strip, {})
    subcat                = cat.fetch(line[1].strip, {})
    subcat[line[2].strip] = line[3].to_i
    cat[line[1].strip]    = subcat
    data[line[0]]         = cat
  end
  data
end

def score_cat(cate)
  total_subs = cate.keys.count
  max_score  = total_subs * 5
  cate.transform_values! { |subcat| score_sub_cat(subcat) }

  total_score = cate.values.sum { |a| a[:plot_score] * 5 }
  cate.merge(total_points: total_score, average: total_score / total_subs, plot_score: total_score.to_f / max_score.to_f,
             values:       cate.values.map { |a| a[:average] },
             ranges:       cate.values.map { |a| 5 },
             ticks:        cate.values.map { |a| 0 },
             labels:       cate.keys)
end

def score_sub_cat(subcat)
  total_questions = subcat.keys.count
  max_score       = total_questions * 5
  total_score     = subcat.values.sum
  subcat.merge(total_points: total_score, average: total_score.to_f / total_questions.to_f,
               plot_score:   total_score.to_f / max_score.to_f,
               values:       subcat.values,
               ranges:       subcat.values.map { |_| 5 },
               ticks:        subcat.values.map { |_| 0 },
               labels:       subcat.keys)
end

def score_overall(categories)
  {
      values: categories.values.map { |v| v[:average] },
      ranges: categories.values.map { |_| 5 },
      ticks:  categories.values.map { |_| 0 },
      labels: categories.keys
  }
end

def var_safe(value)
  value.delete(' /.:-')
end

def render_chart(title, data, template, colors = nil)
  colors ||= $config[:colors]
  chart_data = data.merge(title: title, var_key: var_safe(title), colors: colors,
                          width: CHART_WIDTH, height: CHART_HEIGHT)
  ERB.new(template).result(binding)
end

def render_chart_to_file(prefix, title, data, chart_template, script_template, allow_links = true, colors = nil)
  colors ||= $config[:colors]
  chart_data = data.merge(title: title, var_key: var_safe(title), colors: colors,
                          width: CHART_WIDTH, height: CHART_HEIGHT, use_nav: allow_links,
                          header_text: $config[:header_text])
  chart_data[:url_prefix] = var_safe(title) unless title == MAIN_TITLE
  chart_data[:chart] = ERB.new(chart_template).result(binding)
  chart_data[:script] = ERB.new(script_template).result(binding)
  file_template = File.read('polar_multi.html.erb')
  File.open("#{prefix}/#{var_safe(title)}.html", 'wb') { |f| f.write(ERB.new(file_template).result(binding)) }
end

def render_data(data, outfile)
  scored          = data.transform_values { |cat| score_cat(cat) }
  chart_template  = File.read('chart.html.erb')
  script_template = File.read('script.html.erb')
  template        = File.read('polar.html.erb')
  File.open("#{outfile}.html", 'wb') { |f| f.write(ERB.new(template).result(binding)) }
end

def multi_file_render(data, prefix)
  full_prefix = "#{prefix}_charts"
  FileUtils.mkdir_p "./#{full_prefix}"
  FileUtils.mkdir_p "./#{full_prefix}/css"
  FileUtils.cp 'polar.css', "./#{full_prefix}/css/polar.css"
  scored          = data.transform_values { |cat| score_cat(cat) }
  chart_template  = File.read('chart.html.erb')
  script_template = File.read('script.html.erb')
  template        = File.read('polar.html.erb')

  render_chart_to_file(full_prefix, MAIN_TITLE, score_overall(scored), chart_template, script_template)
  scored.each do |cat_name, category|
    next unless category.is_a?(Hash)
    category[:display_title] = "<a href='#{MAIN_TITLE}.html'>#{MAIN_TITLE}</a> - #{cat_name}"
    render_chart_to_file(full_prefix, cat_name, category, chart_template, script_template)
    category.each do |subcat_name, subcat|
      next unless subcat.is_a?(Hash)
      subcat[:display_title] = "<a href='#{cat_name}.html'>#{cat_name}</a> - #{subcat_name}"
      render_chart_to_file(full_prefix, "#{cat_name} - #{subcat_name}", subcat, chart_template, script_template, false)
    end
  end
end

$config = File.open('config.yml', 'r') { |f| YAML.load(f.read) }
data    = read_data(ARGV[0])
multi_file_render(data, ARGV[0])

binding.pry if Nenv.debug?
puts 'done'