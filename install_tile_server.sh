#!/bin/bash
# -*- ENCODING: UTF-8 -*-

# this file was built following the steps from https://switch2osm.org/serving-tiles/manually-building-a-tile-server-14-04/

# install dependencies
PASO_1=false
# install postgreSQL and postgis
PASO_2=false
# create database and user
PASO_3=false
# create linux user with the same name of postgres user
PASO_4=false
# enable postgis on database  
PASO_5=false
# install osm2pgsql
PASO_6=false
# install mapnik
PASO_7=false
# install mod_tile and renderd
PASO_8=false
# install stylesheet for map
PASO_9=false
# compiling the stylesheet
PASO_10=true
# configuring webserver
PASO_11=true

USER_POSTGRES=transapp
USER_LINUX=transapp
DBNAME_POSTGRES=gis
PATH_SRC=~/Desktop/src

# We will use /usr/local/share/maps/style as a common directory for our stylesheet files and resources.
PATH_STYLESHEET=/usr/local/share/maps/style

# it is aproximately 700MB 
if $PASO_1; then 
    echo "PASO 1 ========================================================="
	sudo apt-get install libboost-all-dev subversion git-core tar unzip wget bzip2 build-essential autoconf libtool libxml2-dev libgeos-dev libgeos++-dev libpq-dev libbz2-dev libproj-dev munin-node munin libprotobuf-c0-dev protobuf-c-compiler libfreetype6-dev libpng12-dev libtiff4-dev libicu-dev libgdal-dev libcairo-dev libcairomm-1.0-dev apache2 apache2-dev libagg-dev liblua5.2-dev ttf-unifont lua5.1 liblua5.1-dev libgeotiff-epsg node-carto 
fi

if $PASO_2; then
    echo "PASO 2 ========================================================="
	sudo apt-get install postgresql postgresql-contrib postgis postgresql-9.3-postgis-2.1
fi

if $PASO_3; then
    echo "PASO 3 ========================================================="
	# answer yes for superuser (although this isn't strictly necessary)
	sudo -u postgres -i createuser $USER_POSTGRES	
	sudo -u postgres -i createdb -E UTF8 -O $USER_POSTGRES $DBNAME_POSTGRES
fi

if $PASO_4; then
    echo "PASO 4 ========================================================="
	sudo useradd -m $USER_LINUX
	sudo passwd $USER_LINUX # use pass “transapp”	
fi

if $PASO_5; then
    echo "PASO 5 ========================================================="
	sudo -u postgres -i psql -d $DBNAME_POSTGRES -c "CREATE EXTENSION postgis;"
	sudo -u postgres -i psql -d $DBNAME_POSTGRES -c "ALTER TABLE geometry_columns OWNER TO $USER_POSTGRES;"
 	sudo -u postgres -i psql -d $DBNAME_POSTGRES -c "ALTER TABLE spatial_ref_sys OWNER TO $USER_POSTGRES;"
fi

# make a directory for dependences's repository 
echo "CREAR CARPETA SRC =============================================="
rm -rf $PATH_SRC
mkdir $PATH_SRC

if $PASO_6; then
    echo "PASO 6 ========================================================="
    # install dependencies
    sudo apt-get install make cmake g++ libboost-dev libboost-system-dev libboost-filesystem-dev libexpat1-dev zlib1g-dev libbz2-dev libpq-dev libgeos-dev libgeos++-dev libproj-dev lua5.2 liblua5.2-dev
    # change path
    cd $PATH_SRC
    git clone git://github.com/openstreetmap/osm2pgsql.git
    cd osm2pgsql
    mkdir build
    cd build
    cmake ..
    make
    sudo make install
fi

if $PASO_7; then
    echo "PASO 7 ========================================================="
    cd $PATH_SRC
    git clone git://github.com/mapnik/mapnik
    cd mapnik
    git branch 2.2 origin/2.2.x
    git checkout 2.2

    python scons/scons.py configure INPUT_PLUGINS=all OPTIMIZATION=3 SYSTEM_FONTS=/usr/share/fonts/truetype/
    make
    sudo make install
    sudo ldconfig
fi

if $PASO_8; then
    echo "PASO 8 ========================================================="
    cd $PATH_SRC
    git clone git://github.com/openstreetmap/mod_tile.git
    cd mod_tile
    ./autogen.sh
    ./configure
    make
    sudo make install
    sudo make install-mod_tile
    sudo ldconfig
fi

# it is aproximately 20MB+423MB+ 
if $PASO_9; then
    echo "PASO 9 ========================================================="
    sudo mkdir $PATH_STYLESHEET
    sudo chown $USER_LINUX $PATH_STYLESHEET
    cd $PATH_STYLESHEET
    sudo -u $USER_LINUX -i wget https://github.com/mapbox/osm-bright/archive/master.zip
    sudo -u $USER_LINUX -i wget http://data.openstreetmapdata.com/simplified-land-polygons-complete-3857.zip
    sudo -u $USER_LINUX -i wget http://data.openstreetmapdata.com/land-polygons-split-3857.zip
    sudo -u $USER_LINUX -i mkdir ne_10m_populated_places_simple
    cd ne_10m_populated_places_simple
    sudo -u $USER_LINUX -i wget http://www.naturalearthdata.com/http//www.naturalearthdata.com/download/10m/cultural/ne_10m_populated_places_simple.zip
    sudo -u $USER_LINUX -i unzip ne_10m_populated_places_simple.zip
    sudo -u $USER_LINUX -i rm ne_10m_populated_places_simple.zip
    cd ..

    # move the downloaded data into the osm-bright-master project directory
    sudo -u $USER_LINUX -i unzip '*.zip'
    sudo -u $USER_LINUX -i mkdir osm-bright-master/shp
    sudo -u $USER_LINUX -i mv land-polygons-split-3857 osm-bright-master/shp/
    sudo -u $USER_LINUX -i mv simplified-land-polygons-complete-3857 osm-bright-master/shp/
    sudo -u $USER_LINUX -i mv ne_10m_populated_places_simple osm-bright-master/shp/

    # to improve performance, we create index files for the larger shapefiles
    sudo -u $USER_LINUX -i cd osm-bright-master/shp/land-polygons-split-3857
    shapeindex land_polygons.shp
    sudo -u $USER_LINUX -i cd ../simplified-land-polygons-complete-3857/
    sudo -u $USER_LINUX -i shapeindex simplified_land_polygons.shp
    cd ../..

    # configuring OSM Bright
    # The OSM Bright stylesheet now needs to be adjusted to include the location of our data files. 
    # We have to Edit the file osm-bright/osm-bright.osm2pgsql.mml
    

fi

if $PASO_10; then
    echo "PASO 10 ========================================================"

fi

if $PASO_11; then
    echo "PASO 11 ========================================================"

fi
