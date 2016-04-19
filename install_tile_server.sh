#!/bin/bash
# -*- ENCODING: UTF-8 -*-

# this file was built following the steps from https://switch2osm.org/serving-tiles/manually-building-a-tile-server-14-04/

# install dependencies
STEP_1=false
# install postgreSQL and postgis
STEP_2=false
# create database and user
STEP_3=false
# create linux user with the same name of postgres user
STEP_4=false
# enable postgis on database  
STEP_5=false
# install osm2pgsql
STEP_6=false
# install mapnik
STEP_7=false
# install mod_tile and renderd
STEP_8=false
# install stylesheet for map
STEP_9=false
# compiling the stylesheet
STEP_10=false
# configuring webserver
STEP_11=false
# tuning the system
STEP_12=true
# Loading data into the server
STEP_13=true
# testing server
STEP_14=true

POSTGRES_USER=transapp
LINUX_USER=transapp
POSTGRES_DBNAME=gis
PATH_SRC=~/Desktop/src

# We will use /usr/local/share/maps/style as a common directory for our stylesheet files and resources.
PATH_STYLESHEET=/usr/local/share/maps/style

# it is aproximately 700MB 
if $STEP_1; then 
    echo "PASO 1 ========================================================="
	sudo apt-get install libboost-all-dev subversion git-core tar unzip wget bzip2 build-essential autoconf libtool libxml2-dev libgeos-dev libgeos++-dev libpq-dev libbz2-dev libproj-dev munin-node munin libprotobuf-c0-dev protobuf-c-compiler libfreetype6-dev libpng12-dev libtiff4-dev libicu-dev libgdal-dev libcairo-dev libcairomm-1.0-dev apache2 apache2-dev libagg-dev liblua5.2-dev ttf-unifont lua5.1 liblua5.1-dev libgeotiff-epsg node-carto 
fi

if $STEP_2; then
    echo "PASO 2 ========================================================="
	sudo apt-get install postgresql postgresql-contrib postgis postgresql-9.3-postgis-2.1
fi

if $STEP_3; then
    echo "PASO 3 ========================================================="
	# answer yes for superuser (although this isn't strictly necessary)
	sudo -u postgres createuser $POSTGRES_USER	
	sudo -u postgres createdb -E UTF8 -O $POSTGRES_USER $POSTGRES_DBNAME
fi

if $STEP_4; then
    echo "PASO 4 ========================================================="
	sudo useradd -m $LINUX_USER
	sudo passwd $LINUX_USER # use pass “transapp”	
fi

if $STEP_5; then
    echo "PASO 5 ========================================================="
	sudo -u postgres psql -d $POSTGRES_DBNAME -c "CREATE EXTENSION postgis;"
	sudo -u postgres psql -d $POSTGRES_DBNAME -c "ALTER TABLE geometry_columns OWNER TO $POSTGRES_USER;"
 	sudo -u postgres psql -d $POSTGRES_DBNAME -c "ALTER TABLE spatial_ref_sys OWNER TO $POSTGRES_USER;"
fi

# make a directory for dependences's repository 
echo "CREAR CARPETA SRC =============================================="
rm -rf $PATH_SRC
mkdir $PATH_SRC

if $STEP_6; then
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

if $STEP_7; then
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

if $STEP_8; then
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
if $STEP_9; then
    echo "PASO 9 ========================================================="
    sudo mkdir -p $PATH_STYLESHEET
    sudo chown $LINUX_USER $PATH_STYLESHEET
    cd $PATH_STYLESHEET
    sudo -u $LINUX_USER wget https://github.com/mapbox/osm-bright/archive/master.zip -P $PATH_STYLESHEET
    sudo -u $LINUX_USER wget http://data.openstreetmapdata.com/simplified-land-polygons-complete-3857.zip -P $PATH_STYLESHEET
    sudo -u $LINUX_USER wget http://data.openstreetmapdata.com/land-polygons-split-3857.zip -P $PATH_STYLESHEET
    sudo -u $LINUX_USER mkdir ne_10m_populated_places_simple
    cd ne_10m_populated_places_simple
    sudo -u $LINUX_USER wget http://www.naturalearthdata.com/http//www.naturalearthdata.com/download/10m/cultural/ne_10m_populated_places_simple.zip -P $PATH_STYLESHEET/ne_10m_populated_places_simple
    sudo -u $LINUX_USER unzip ne_10m_populated_places_simple.zip
    sudo -u $LINUX_USER rm ne_10m_populated_places_simple.zip
    cd ..

    # move the downloaded data into the osm-bright-master project directory
    sudo -u $LINUX_USER unzip '*.zip'
    sudo -u $LINUX_USER mkdir osm-bright-master/shp
    sudo -u $LINUX_USER mv land-polygons-split-3857 osm-bright-master/shp/
    sudo -u $LINUX_USER mv simplified-land-polygons-complete-3857 osm-bright-master/shp/
    sudo -u $LINUX_USER mv ne_10m_populated_places_simple osm-bright-master/shp/

    # to improve performance, we create index files for the larger shapefiles
    cd osm-bright-master/shp/land-polygons-split-3857
    sudo -u $LINUX_USER shapeindex land_polygons.shp
    cd ../simplified-land-polygons-complete-3857/
    sudo -u $LINUX_USER shapeindex simplified_land_polygons.shp
    cd ../..

    # configuring OSM Bright
    # The OSM Bright stylesheet now needs to be adjusted to include the location of our data files. 
    # We have to Edit the file osm-bright/osm-bright.osm2pgsql.mml
    
    URL_SLP="\"file\": \"http://data.openstreetmapdata.com/simplified-land-polygons-complete-3857.zip\","
    NEW_URL_SLP="\"file\": \"/usr/local/share/maps/style/osm-bright-master/shp/simplified-land-polygons-complete-3857/simplified_land_polygons.shp\", \"type\": \"shape\","
    sudo -u $LINUX_USER sed -in "s|$URL_SLP|$NEW_URL_SLP|" osm-bright/osm-bright.osm2pgsql.mml

    URL_LPS="\"file\": \"http://data.openstreetmapdata.com/land-polygons-split-3857.zip\""
    NEW_URL_LPS="\"file\": \"/usr/local/share/maps/style/osm-bright-master/shp/land-polygons-split-3857/land_polygons.shp\", \"type\": \"shape\","
    sudo -u $LINUX_USER sed -in "s|$URL_LPS|$NEW_URL_LPS|" osm-bright/osm-bright.osm2pgsql.mml

    URL_PPS="\"file\": \"http://mapbox-geodata.s3.amazonaws.com/natural-earth-1.4.0/cultural/10m-populated-places-simple.zip\""
    NEW_URL_PPS="\"file\": \"/usr/local/share/maps/style/osm-bright-master/shp/ne_10m_populated_places_simple/ne_10m_populated_places_simple.shp\", \"type\": \"shape\""
    sudo -u $LINUX_USER sed -in "s|$URL_PPS|$NEW_URL_PPS|" osm-bright/osm-bright.osm2pgsql.mml

    # to replace srs and srs-name with unique line
    SOURCE="\"srs\": \"\","
    sudo -u $LINUX_USER sed -in "s|$SOURCE||" osm-bright/osm-bright.osm2pgsql.mml
    SOURCE_NAME="\"srs-name\": \"autodetect\""
    NEW_SOURCE_NAME="\"srs\": \"+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs\""
    sudo -u $LINUX_USER sed -in "s|$SOURCE_NAME|$NEW_SOURCE_NAME|" osm-bright/osm-bright.osm2pgsql.mml

fi

if $STEP_10; then
    echo "PASO 10 ========================================================"
    cd $PATH_STYLESHEET/osm-bright-master
    sudo -u $LINUX_USER cp configure.py.sample configure.py

    # Change directory
    OLD_PATH="~/Documents/MapBox/project"
    NEW_PATH="/usr/local/share/maps/style"

    sudo -u $LINUX_USER sed -in "s|$OLD_PATH|$NEW_PATH|" configure.py

    # Replace the database name
    OLD_DBNAME="\"osm\""

    sudo -u $LINUX_USER sed -in "s|$OLD_DBNAME|\"$POSTGRES_DBNAME\"|" configure.py

    sudo -u $LINUX_USER ./make.py
    cd ../OSMBright
    sudo -u $LINUX_USER carto project.mml | sudo -u $LINUX_USER tee OSMBright.xml
fi

if $STEP_11; then
    echo "PASO 11 ========================================================"
    PATH_RENDERD_FILE=/usr/local/etc/renderd.conf
    
    # we need to be root
    OLD_SOCKETNAME=";socketname"
    NEW_SOCKETNAME="socketname"
    sudo sed -in "s|$OLD_SOCKETNAME|$NEW_SOCKETNAME|" $PATH_RENDERD_FILE

    OLD_PLUGINS_DIR="plugins_dir=/usr/lib/mapnik/input"
    NEW_PLUGINS_DIR="plugins_dir=/usr/local/lib/mapnik/input"
    sudo sed -in "s|$OLD_PLUGINS_DIR|$NEW_PLUGINS_DIR|" $PATH_RENDERD_FILE
    
    OLD_FONT_DIR="font_dir=/usr/share/fonts/truetype"
    NEW_FONT_DIR="font_dir=/usr/share/fonts/truetype/ttf-dejavu"
    sudo sed -in "s|$OLD_FONT_DIR|$NEW_FONT_DIR|" $PATH_RENDERD_FILE

    OLD_XML_PATH="XML=/home/jburgess/osm/svn.openstreetmap.org/applications/rendering/mapnik/osm-local.xml"
    NEW_XML_PATH="XML=$PATH_STYLESHEET/OSMBright/OSMBright.xml"
    sudo sed -in "s|$OLD_XML_PATH|$NEW_XML_PATH|" $PATH_RENDERD_FILE

    OLD_HOST="HOST=tile.openstreetmap.org"
    NEW_HOST="HOST=localhost"
    sudo sed -in "s|$OLD_HOST|$NEW_HOST|" $PATH_RENDERD_FILE

    # set max zoom to level 19 (standard = 18)
    OLD_MAXZOOM=";MAXZOOM=18"
    NEW_MAXZOOM="MAXZOOM=19"
    sudo sed -in "s|$OLD_MAXZOOM|$NEW_MAXZOOM|" $PATH_RENDERD_FILE

    # Create the files required for the mod_tile system to run
    sudo mkdir /var/run/renderd
    sudo chown $LINUX_USER /var/run/renderd
    sudo mkdir /var/lib/mod_tile
    sudo chown $LINUX_USER /var/lib/mod_tile

    MODTILE_FILE="/etc/apache2/conf-available/mod_tile.conf"
    sudo touch $MODTILE_FILE
    sudo echo "LoadModule tile_module /usr/lib/apache2/modules/mod_tile.so" | sudo tee $MODTILE_FILE 

    # modify /etc/apache2/sites-available/000-default.conf
    APACHE_CONF_FILE=/etc/apache2/sites-available/000-default.conf

    MODTILE_OPTS="\n\nLoadTileConfigFile $PATH_RENDERD_FILE\n   ModTileRenderdSocketName /var/run/renderd/renderd.sock\n # Timeout before giving up for a tile to be rendered\n   ModTileRequestTimeout 0\n   # Timeout before giving up for a tile to be rendered that is otherwise missing\n  ModTileMissingRequestTimeout 30\n\n"
    
    sudo sed -in "s|</VirtualHost>|$MODTILE_OPTS</VirtualHost>|" $APACHE_CONF_FILE

    # restart apache
    sudo a2enconf mod_tile
    sudo service apache2 reload
fi

if $STEP_12; then
    echo "PASO 12 ========================================================"
    POSTGRES_CONF=/etc/postgresql/9.3/main/postgresql.conf
    
    #shared_buffers = 128MB

    OLD_CHECKPOINT_SEGMENTS="#checkpoint_segments = 3        # in logfile segments, min 1, 16MB each"
    NEW_CHECKPOINT_SEGMENTS="checkpoint_segments = 20        # in logfile segments, min 1, 16MB each"
    sudo sed -in "s|$OLD_CHECKPOINT_SEGMENTS|$NEW_CHECKPOINT_SEGMENTS|" $POSTGRES_CONF

    # maintenance work mem
    OLD_MWM="#maintenance_work_mem = 16MB        # min 1MB"
    NEW_MWM="maintenance_work_mem = 256MB        # min 1MB"
    sudo sed -in "s|$OLD_MWM|$NEW_MWM|" $POSTGRES_CONF

    OLD_AUTOVACUUM="#autovacuum = on            # Enable autovacuum subprocess?  'on'"
    NEW_AUTOVACUUM="autovacuum = off            # Enable autovacuum subprocess?  'on'"
    sudo sed -in "s|$OLD_AUTOVACUUM|$NEW_AUTOVACUUM|" $POSTGRES_CONF

    # set kernel 
    SYSCTL_PATH=/etc/sysctl.conf

    SYSCTL_SET="\n\n# Increase kernel shared memory segments - needed for large databases\nkernel.shmmax=268435456"
    #no funciona!!!!
    sudo echo $SYSCTL_SET | sudo tee --append $SYSCTL_PATH

    # reboot the computer
    #sudo sysctl kernel.shmmax
fi

if $STEP_13; then
    echo "PASO 13 ========================================================"

    DATA_PATH=/usr/local/share/maps/planet
    sudo mkdir $DATA_PATH
    sudo chown $LINUX_USER $DATA_PATH
    cd $DATA_PATH

    # get Chile data
    wget http://download.geofabrik.de/south-america/chile-latest.osm.pbf

    # importing data to postgres
    osm2pgsql --slim -d gis -C 16000 --number-processes 3 $DATA_PATH/chile-latest.osm.pbf

fi

# turn on server
if $STEP_14; then
    echo "PASO 13 ========================================================"

    sudo -u $LINUX_USER  renderd -f -c /usr/local/etc/renderd.conf

    sudo service apache2 reload

    # now, try http://localhost/osm_tiles/0/0/0.png
fi
