require 'sinatra'
require 'pry'
require_relative 'polar_shared'
require_relative 'recursive_zip'

$config = File.open('config.yml', 'r') { |f| YAML.load(f.read) }

set :bind, '0.0.0.0'

get '/' do
  send_file File.join(settings.public_folder, 'index.html')
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
  filename = params['csv_file']['filename']
  data = read_data(params['csv_file']['tempfile'])
  prepared_by = params.fetch('prepared_by', 'Centric Consulting')
  prepared_by = 'Centric Consulting' if prepared_by.empty?
  meta = { client_name: params['client_name'], title: params['title'],
           initial_filename: params.fetch('initial_filename', filename),
           prepared_by: prepared_by }
  path_key = meta[:initial_filename]
  output_path = "public/chart_data/#{path_key}"
  FileUtils.mkdir_p "./#{output_path}"
  File.open("#{output_path}.meta.yaml", 'w') { |f| f.write(YAML.dump(meta)) }
  multi_file_render(data, output_path, meta)
  redirect "/charts/#{path_key}"
end