# Radial Polar Chart Generator

This app will take data in a CSV file and generate a linked series of HTML charts.

The CSV file should be in the form of: category, subcategory, detail, score

Score is expected to be in the range of 0-5.  Floating points are fine.

## Run from source
First run the following on the command line:
```
bundle install
bundle exec ruby polar_srv.rb
``` 

Then visit http://localhost:4567

## Run from Docker (no source needed)
First run the following on the command line:
```
docker run --rm -p 3000:3000 jdonavan/caca
``` 

Then visit http://localhost:3000
