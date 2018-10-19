# encoding: UTF-8
#!/usr/bin/env ruby
require 'pry'
require 'erb'
require 'nenv'
require 'csv'
require 'chroma'



CHART_WIDTH  = 800
CHART_HEIGHT = 580
MAIN_TITLE = 'Overview'

def read_data(file)
  data = Hash.new
  CSV.foreach(file, encoding: 'UTF-8') do |line|
    next unless line[3] =~ /\d+/
    cat                   = data.fetch(line[0].strip, {})
    subcat                = cat.fetch(line[1].strip, {})
    subcat[line[2].strip] = line[3].to_i
    cat[line[1].strip]    = subcat
    data[line[0]]         = cat
  end
  data
end

def score_cat(cate, meta)
  total_subs = cate.keys.count
  max_score  = total_subs * meta[:max_score]
  cate.transform_values! { |subcat| score_sub_cat(subcat, meta) }

  total_score = cate.values.sum { |a| a[:plot_score] * meta[:max_score] }
  cate.merge(total_points: total_score, average: total_score / total_subs, plot_score: total_score.to_f / max_score.to_f,
             values:       cate.values.map { |a| a[:average] },
             ranges:       cate.values.map { |a| meta[:max_score] },
             ticks:        cate.values.map { |a| 0 },
             labels:       cate.keys)
end

def score_sub_cat(subcat, meta)
  total_questions = subcat.keys.count
  max_score       = total_questions * meta[:max_score]
  total_score     = subcat.values.sum
  subcat.merge(total_points: total_score, average: total_score.to_f / total_questions.to_f,
               plot_score:   total_score.to_f / max_score.to_f,
               values:       subcat.values,
               ranges:       subcat.values.map { |_| meta[:max_score] },
               ticks:        subcat.values.map { |_| 0 },
               labels:       subcat.keys)
end

def score_overall(categories, meta)
  {
      values: categories.values.map { |v| v[:average] },
      ranges: categories.values.map { |_| meta[:max_score] },
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

def render_chart_to_file(output_path, title, data, chart_template, script_template, meta, allow_links = true, colors = nil)
  chart_data = data.merge(title: title, var_key: var_safe(title),
                           use_nav: allow_links, header_text: meta[:title])
  chart_data[:url_prefix] = var_safe(title) unless title == MAIN_TITLE
  chart_data[:max_label_len] = chart_data[:labels].max_by(&:length).length
  chart_data[:chart] = ERB.new(chart_template).result(binding)
  chart_data[:script] = ERB.new(script_template).result(binding)
   file_template = File.read('polar_multi.html.erb')
  File.open("#{output_path}/#{var_safe(title)}.html", 'wb') { |f| f.write(ERB.new(file_template).result(binding)) }
end

def render_data(data, outfile, meta)
  scored          = data.transform_values { |cat| score_cat(cat, meta) }
  chart_template  = File.read('chart.html.erb')
  script_template = File.read('script.html.erb')
  template        = File.read('polar.html.erb')
  File.open("#{outfile}.html", 'wb') { |f| f.write(ERB.new(template).result(binding)) }
end

def random_data(outfile, max_score = 5)
  data = {}
  num_cats = rand(5) + 4
  num_cats.times do |i|
    data["Category #{i + 1}"] = {}
    num_subcats = rand(7) + 3
    num_subcats.times do |si|
      subcat = {}
      num_questions = rand(7) + 3
      num_questions.times do |q|
        subcat["Detail #{q + 1}"] = rand(4) +1
      end
      data["Category #{i + 1}"]["Subcategory #{si + 1}"] = subcat
    end
  end
  results = []
  data.each do |dk, dv|
    dv.each do |ck, cv|
      cv.each do |sk, sv|
        results << [dk, ck, sk, sv].join(',')
      end
    end
  end
  results
end


def generate_linear_colors(base_color, data, base_colors, step_size = 10)
  base_colors
end

def generate_gradient_colors(base_color, data, base_colors, step_size = 9)
  colors = data[:labels].count.times.map { |n| base_color.paint.lighten(step_size * n ) }
  return colors if step_size == 1 || colors.none? { |c| c.brightness > 220 }
  generate_gradient_colors(base_color, data, base_colors, step_size - 1)
end

def generate_score_colors(base_color, data, base_colors, step_size = 9)
  #binding.pry
  colors = data[:values].map { |v| base_color.paint.lighten(step_size * (data[:ranges][0].to_f - v)) }
  return colors if step_size == 1 || colors.none? { |c| c.brightness > 220 }
  generate_score_colors(base_color, data, base_colors, step_size - 1)
end

def multi_file_render(data, output_path, meta)
  FileUtils.mkdir_p "./#{output_path}"
  FileUtils.mkdir_p "./#{output_path}/css"
  FileUtils.cp 'polar.css', "./#{output_path}/css/polar.css"
  scored          = data.transform_values { |cat| score_cat(cat, meta) }
  chart_template  = File.read('chart.html.erb')
  script_template = File.read('script.html.erb')
  template        = File.read('polar.html.erb')

  base_colors = meta[:colors]
  cat_index = 0
  render_chart_to_file(output_path, MAIN_TITLE, score_overall(scored, meta).merge(display_title: '', colors: base_colors), chart_template, script_template, meta)
  scored.each do |cat_name, category|
    next unless category.is_a?(Hash)
    cat_color = base_colors[cat_index]
    color_mode = meta.fetch(:color_mode, :score)
    category[:colors] = send("generate_#{color_mode}_colors", cat_color, category, base_colors)
    #binding.pry if cat_name == 'Automation'
    category[:display_title] = "<a href='#{MAIN_TITLE}.html'>#{MAIN_TITLE}</a> - #{cat_name}"
    render_chart_to_file(output_path, cat_name, category, chart_template, script_template, meta)
    category.each do |subcat_name, subcat|
      next unless subcat.is_a?(Hash)
      #binding.pry if subcat_name == 'Version Control'
      subcat[:colors] = send("generate_#{color_mode}_colors", cat_color, subcat, base_colors)
      subcat[:display_title] = "<a href='Overview.html'>Overview</a> - <a href='#{var_safe(cat_name)}.html'>#{cat_name}</a> - #{subcat_name}"
      render_chart_to_file(output_path, "#{cat_name} - #{subcat_name}", subcat, chart_template, script_template, meta, false)
    end
    cat_index += 1
  end
end
