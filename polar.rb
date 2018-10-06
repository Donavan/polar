#!/usr/bin/env ruby
require 'pry'
require 'erb'

def read_data(filename = ARGV[0])
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
             scores: cate.values.map { |a| a[:average] }.join(','),
             ranges: cate.values.map { |a| 5 }.join(','),
             ticks: cate.values.map { |a| 0 }.join(','),
             names: cate.keys.join(','))
end

def score_sub_cat(subcat)
  #binding.pry
  total_questions = subcat.keys.count
  max_score = total_questions * 5
  total_score = subcat.values.sum
  subcat.merge(total_points: total_score, average: total_score.to_f / total_questions.to_f,
               plot_score: total_score.to_f / max_score.to_f,
               values: subcat.values.join(','),
               ranges: subcat.values.map { |a| 5 }.join(','),
               ticks: subcat.values.map { |a| 0 }.join(','),
               names: subcat.keys.join(','))
end


def score_overall(categories)
  { values: categories.values.map { |v| v[:average] },
    ranges: categories.values.map { |a| 5 }.join(','),
    ticks: categories.values.map { |a| 0 }.join(','),
    names: categories.keys.join(',')
  }
end

read_data

scored = data.transform_values { |cat| score_cat(cat) }
overall = score_overall(scored)
template = File.read('index.html.erb')
File.open("#{ARGV[0]}.html", 'wb') { |f| f.write(ERB.new(template).result(binding)) }
binding.pry

puts 'done'