# encoding: UTF-8
require 'sinatra'
require 'pry'
require_relative 'polar_shared'
require_relative 'recursive_zip'

$config = File.open('config.yml', 'r') { |f| YAML.load(f.read) }

set :bind, '0.0.0.0'

get '/' do
  palettes = File.open('public/palettes.json', 'r') { |f| JSON.load(f.read) }
  template = File.read('index.html.erb')
  ERB.new(template).result(binding)
end

get '/charts/:which' do
  meta = File.open("public/chart_data/#{params['which']}.meta.yaml", 'r') { |f| YAML.load(f.read) }
  template = File.read('chart_preview.html.erb')
  page_data = {
      which: params['which'],
      chart_uri: "/chart_data/#{params['which']}/Overview.html"
  }
  ERB.new(template).result(binding)
end

get '/zip/:which' do
  path_key = "chart_data/#{params['which']}"
  gen = ZipFileGenerator.new("public/#{path_key}","public/#{path_key}_charts.zip")
  FileUtils.safe_unlink("public/#{path_key}_charts.zip")
  gen.write
  send_file("public/#{path_key}_charts.zip", :disposition => 'attachment', :filename => File.basename("#{params['which']}_charts.zip"))
end

post '/charts' do
  palettes = File.open('public/palettes.json', 'r') { |f| JSON.load(f.read) }
  filename = params['csv_file']['filename']
  data = read_data(params['csv_file']['tempfile'])
  prepared_by = params.fetch('prepared_by', 'Centric Consulting')
  prepared_by = 'Centric Consulting' if prepared_by.empty?
  max_score = params['max_score'].to_i
  tick_size = params['ticks_size'].to_i.positive? ? params['ticks_size'].to_i : max_score / 5
  custom_colors = params['custom_colors'].gsub(',', ' ').split(' ')
  custom_colors.map! { |c| c.strip.start_with?('#') ? c.strip : "##{c.strip}" }
  colors = params['palette'] == 'Custom' ? custom_colors : palettes[params['palette']]

  meta = { client_name: params['client_name'], title: params['title'], custom_colors: params['custom_colors'],
           color_mode: params['color_mode'], initial_filename: params.fetch('initial_filename', filename),
           prepared_by: prepared_by, max_score: max_score, tick_size: tick_size, colors: colors,
           palette: params['palette'], chart_width: params['chart_width'], chart_height: params['chart_height'] }
  %i[display_legend display_copyright display_title display_branding].each do |flag|
    meta[flag] = params[flag.to_s].to_s == 'on'
  end

  path_key = meta[:initial_filename]
  output_path = "public/chart_data/#{path_key}"
  FileUtils.mkdir_p "./#{output_path}"
  File.open("#{output_path}.meta.yaml", 'w') { |f| f.write(YAML.dump(meta)) }
  multi_file_render(data, output_path, meta)
  redirect "/charts/#{path_key}"
end