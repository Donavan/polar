# Radial Polar Chart Generator

This app will take data in a CSV file and generate a linked series of HTML charts.

The CSV file should be in the form of: category, subcategory, detail, score

Score is expected to be in the range of 0-5.  Floating points are fine.

Run the app with: ruby polar.rb CSV_FILENAME

When complete open: CSV_FILENAME/Overview.html