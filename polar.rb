#!/usr/bin/env ruby
require 'pry'
require 'erb'
require 'nenv'

CHART_WIDTH = 800
CHART_HEIGHT = 500

def read_data(filename)
  lines = File.readlines(filename).map { |l| l.split(',') }
  data = {}

  lines.each do |line|
    cat = data.fetch(line[0].strip, {})
    subcat = cat.fetch(line[1].strip, {})
    subcat[line[2].strip] = line[3].to_i
    cat[line[1].strip] = subcat
    data[line[0]] = cat
  end
  data
end

def score_cat(cate)
  total_subs = cate.keys.count
  max_score = total_subs * 5
  cate.transform_values! { |subcat| score_sub_cat(subcat) }

  total_score = cate.values.sum { |a| a[:plot_score] * 5 }
  cate.merge(total_points: total_score, average: total_score / total_subs, plot_score: total_score.to_f / max_score.to_f,
             values: cate.values.map { |a| a[:average] },
             ranges: cate.values.map { |a| 5 },
             ticks: cate.values.map { |a| 0 },
             labels: cate.keys)
end

def score_sub_cat(subcat)
  total_questions = subcat.keys.count
  max_score = total_questions * 5
  total_score = subcat.values.sum
  subcat.merge(total_points: total_score, average: total_score.to_f / total_questions.to_f,
               plot_score: total_score.to_f / max_score.to_f,
               values: subcat.values,
               ranges: subcat.values.map { |_| 5 },
               ticks: subcat.values.map { |_| 0 },
               labels: subcat.keys)
end

def score_overall(categories)
  {
    values: categories.values.map { |v| v[:average] },
    ranges: categories.values.map { |_| 5 },
    ticks: categories.values.map { |_| 0 },
    labels: categories.keys
  }
end

def var_safe(value)
  value.delete(' /.:-')
end

def render_chart(title, data, template)
  chart_data = data.merge(title: title, var_key: var_safe(title),
                          width: CHART_WIDTH, height: CHART_HEIGHT)
  ERB.new(template).result(binding)
end

def render_overall(data, template)
  render_chart('Overall', score_overall(data), template)
end

def render_category(category_name, category, template)
  render_chart(category_name, category, template)
end

def render_subcategory(category_name, subcategory_name, subcategory, template)
  render_chart("#{category_name} - #{subcategory_name}", subcategory, template)
end

def render_data(data, outfile)
  scored = data.transform_values { |cat| score_cat(cat) }
  chart_template = File.read('chart.html.erb')
  script_template = File.read('script.html.erb')
  template = File.read('polar.html.erb')
  File.open("#{outfile}.html", 'wb') { |f| f.write(ERB.new(template).result(binding)) }
end

data = read_data(ARGV[0])
render_data(data, ARGV[0])

binding.pry if Nenv.debug?
puts 'done'