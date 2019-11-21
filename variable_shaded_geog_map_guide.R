library(SPARQL)
library(dplyr)
library(leaflet)
library(rgdal)
library(mapview)
library(webshot)

### Stage 01 - collect data you wish to map ###

# We need a variable to measure on our chosen geog. If you have a dataframe that contains your 
# chosen geography level and the variable column you wish to map, then you may skip this stage. 
# For the purposes of this tutorial, we will use SIMD ranking obtained from stats.gov SPARQL API:

query <- 'PREFIX qb: <http://purl.org/linked-data/cube#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX sdmx: <http://purl.org/linked-data/sdmx/2009/concept#>
PREFIX data: <http://statistics.gov.scot/data/>
PREFIX sdmxd: <http://purl.org/linked-data/sdmx/2009/dimension#>
PREFIX mp: <http://statistics.gov.scot/def/measure-properties/>
PREFIX stat: <http://statistics.data.gov.uk/def/statistical-entity#>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
SELECT ?dataZone ?SIMDrank
WHERE {
    ?indicator qb:dataSet data:scottish-index-of-multiple-deprivation-2016;
              <http://statistics.gov.scot/def/dimension/simdDomain> <http://statistics.gov.scot/def/concept/simd-domain/simd>;
              mp:rank ?SIMDrank;
              sdmxd:refPeriod <http://reference.data.gov.uk/id/year/2016> ;
              sdmxd:refArea ?area.
    ?area rdfs:label ?dataZone.
}'

# For a comprehensive guide on constructing tailored SPARQL queries, see https://guides.statistics.gov.scot/article/22-querying-data-with-sparql

# SPARQL endpoint to retrive the data
endpoint <- "http://statistics.gov.scot/sparql"
# Assign output of SPARQL query to 'qddata'
qddata <- SPARQL(endpoint, query)
# Assign results of SPARQL query to data frame 'SIMDrank'
SIMDrank <- qddata$results

View(SIMDrank)

# As you can see, we now have a dataframe listing the SIMD rank per datazone. Now we need map data.
# Again, if you have the dataframe already as a csv or excel file, simply upload it at this point instead.

### Stage 02 - Collecting map geography polygons ###

# You must now obtain a shapefile that contains the polygon shapes of your chosen geography .
# For the purposes of this tutorial, we will be looking at the datazone level.

# For this, we require the geodatabase that contains the shapefiles of datazones. This can be found at:
# https://data.gov.uk/dataset/ab9f1f20-3b7f-4efa-9bd2-239acf63b540/data-zone-boundaries-2011
# Download this to your machine.

# Note that if you wished you could also download the geodatabase that contains SPC or local authority level polygons.
# These polygons simply draw out the area of each geography according to their geographic location.

# After downloading gdb, read in appropriate layer.
dz_boundaries <- readOGR(dsn="~/Downloads/SG_DataZoneBdry_2011", layer="SG_DataZone_Bdry_2011")

# Convert easting and northing to lat and long (essential as leaflet cannot read easting and northings).
wgs84 = '+proj=longlat +datum=WGS84'
dz_boundaries <- spTransform(dz_boundaries, CRS(wgs84))

# Now we have two items:
# 1. a spatial dataframe that maps out our datazones.
# 2. a dataframe with our chosen variable (SIMD rank) per datazone.

# Now we need to join them by a common column - their datazone names.

# Join spatial dataframe to SIMD rank dataframe by common column - name.
dz_merged <- merge(dz_boundaries, SIMDrank, by.x = "Name", 
                   by.y = "dataZone", all.x = FALSE, duplicateGeoms = TRUE)

### Stage 03 - Put it all together in an interactive leaflet map ###

# Leaflet will require several things to create our map:

# 1. A colour palette and instructions on how often to change the shading.
# 2. The argument telling it what variable value determines this shading.

# Create bins and palette for mean SIMD rank - we will tell it to deepen the shade for every 500 increase.
bins <- c(0, 500, 1000, 1500, 2000, 2500, 3000, 3500, 4000, 4500, 5000, Inf)
pal <- colorBin("YlOrRd", domain = dz_merged$SIMDrank, bins = bins)

# Plot mean SIMD rank for each polygon in our datazone merged table.
map <- leaflet(dz_merged) %>% 
  setView(-3.2008, 55.9452, 15) %>% # Here you control the initial viewpoint coordinates (We've set this one to Edinburgh city centre).
  addProviderTiles("CartoDB.Positron", # This uplaods the background map using a standard open-source base.
                   options= providerTileOptions(opacity = 0.99)) %>% 
  addPolygons(fillColor = ~pal(SIMDrank), # Here you enter your chosen var by column name.
              weight = 2,
              opacity = 1,
              color = "white",
              dashArray = "3",
              fillOpacity = 0.7,
              highlight = highlightOptions(
                weight = 2,
                color = "#666",
                dashArray = "",
                fillOpacity = 0.7,
                bringToFront = TRUE),
              label=~paste(dz_merged$DataZone), # Here you can control the label output.
              labelOptions = labelOptions(textsize = "15px",
                                          direction = "auto"))

map

# All works fine and shows every datazone in Scotland but this is bulky and extensive and takes forever to load.
# What if we just want particular datazones?

# If you want to look at a particular group of datazones, create a subset dataframe:
subset <- subset(dz_merged, grepl("^Tollcross", dz_merged$Name) | 
                   grepl("^Meadows and Southside", dz_merged$Name) | 
                   grepl("^Old Town, Princes Street and Leith Street", dz_merged$Name))
subset_df <- as.data.frame(subset)
# Here we filter our original dataframe downloaded from stats.gov according to whatever criteria we wish.

# Now we map them using SIMD rankings again but instead pass leaflet the filtered spatial dataframe.

map <- leaflet(subset) %>% 
  setView(-3.2008, 55.9452, 15) %>% # Set View controls where the snapshot will be taken.
  addProviderTiles("CartoDB.Positron", 
                   options= providerTileOptions(opacity = 0.99)) %>% 
  addPolygons(fillColor = ~pal(SIMDrank),
              weight = 2,
              opacity = 1,
              color = "white",
              dashArray = "3",
              fillOpacity = 0.7,
              highlight = highlightOptions(
                weight = 2,
                color = "#666",
                dashArray = "",
                fillOpacity = 0.7,
                bringToFront = TRUE),
              label=~paste(subset$DataZone),
              labelOptions = labelOptions(textsize = "15px",
                                          direction = "auto")) %>% 
  addLegend(pal = pal, 
            values = ~SIMDrank, 
            opacity = 0.7, 
            title = "SIMD rank",
            position = "bottomright") 

map

# Now we have our desired map with shading to show our desired changes in a given variable.
# Make sure to set the initial view to reflect what you want your output to be. This initial view
# is what will be xported to pdf / png.

### Stage 04 - Export these maps as pdf / png using mapview package ###
webshot::install_phantomjs() # Only required once.
mapshot(map, file = "~/Desktop/R Code Examples/Rplot.png") 

