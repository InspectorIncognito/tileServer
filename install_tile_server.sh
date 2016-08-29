#!/bin/bash
# -*- ENCODING: UTF-8 -*-

# this file was built following the steps from:
#    https://switch2osm.org/serving-tiles/manually-building-a-tile-server-14-04/
#    https://wiki.debian.org/OSM/tileserver/jessie#Install_mod_tile

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
STEP_10=true
# configuring webserver
STEP_11=false
# tuning the system
STEP_12=false

# End of The first stage. Reboot server and continue 

# Loading data into the server
STEP_13=false
# testing server
STEP_14=false
# setting renderd to run automatically 
STEP_15=false

INSTALL_DIRECTORY=.
POSTGRES_USER=transapp
LINUX_USER=transapp
POSTGRES_DBNAME=gis
PATH_SRC=~/Desktop/src

# We will use /usr/local/share/maps/style as a common directory for our stylesheet files and resources.
PATH_STYLESHEET=/usr/local/share/maps/style

# it is aproximately 700MB 
if $STEP_1; then 
    echo "PASO 1 ========================================================="
    sudo apt-get install libboost-all-dev subversion git-core tar unzip wget bzip2 build-essential autoconf libtool libxml2-dev libgeos-dev libgeos++-dev libpq-dev libbz2-dev libproj-dev munin-node munin libprotobuf-c-dev protobuf-c-compiler libfreetype6-dev libpng12-dev libtiff5-dev libicu-dev libgdal-dev libcairo2-dev libcairomm-1.0-dev apache2 apache2-dev libagg-dev liblua5.2-dev ttf-unifont lua5.1 liblua5.1-0-dev libgeotiff-epsg node-carto 
fi

if $STEP_2; then
    echo "PASO 2 ========================================================="
    sudo apt-get install postgresql postgresql-contrib postgis postgis
fi

if $STEP_3; then
    echo "PASO 3 ========================================================="
    # answer yes for superuser (although this isn't strictly necessary)
    read -p "USE PASS 'transapp' (lowercase and whitout quote)" -n 1 -s
    sudo -u postgres createuser $POSTGRES_USER    
    sudo -u postgres createdb -E UTF8 -O $POSTGRES_USER $POSTGRES_DBNAME
fi

if $STEP_4; then
    echo "PASO 4 ========================================================="
    sudo useradd -m $LINUX_USER
    read -p "USE PASS 'transapp' (lowercase and whitout quote)" -n 1 -s
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
if [ ! -d "$PATH_SRC" ]; then
    sudo mkdir -p $PATH_SRC
fi

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

    # data 
    sudo -u $LINUX_USER wget http://data.openstreetmapdata.com/simplified-land-polygons-complete-3857.zip -P $PATH_STYLESHEET
    sudo -u $LINUX_USER wget http://data.openstreetmapdata.com/land-polygons-split-3857.zip -P $PATH_STYLESHEET
    sudo -u $LINUX_USER mkdir ne_10m_populated_places_simple
    cd ne_10m_populated_places_simple
    sudo -u $LINUX_USER wget http://www.naturalearthdata.com/http//www.naturalearthdata.com/download/10m/cultural/ne_10m_populated_places_simple.zip -P $PATH_STYLESHEET/ne_10m_populated_places_simple
    sudo -u $LINUX_USER unzip ne_10m_populated_places_simple.zip
    sudo -u $LINUX_USER rm ne_10m_populated_places_simple.zip
    cd ..

    # stylesheets
    # OSMBright
    sudo -u $LINUX_USER wget https://github.com/mapbox/osm-bright/archive/master.zip -P $PATH_STYLESHEET
    # OSMBRight-Smartrak
    #sudo -u $LINUX_USER https://github.com/jacobtoye/osm-bright/archive/master.zip -P $PATH_STYLESHEET

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
    OSM_BRIGHT_MML=./osm-bright/osm-bright.osm2pgsql.mml

    URL_SLP="\"file\": \"http://data.openstreetmapdata.com/simplified-land-polygons-complete-3857.zip\","
    NEW_URL_SLP="\"file\": \"/usr/local/share/maps/style/osm-bright-master/shp/simplified-land-polygons-complete-3857/simplified_land_polygons.shp\", \"type\": \"shape\","
    sudo -u $LINUX_USER sed -in "s|$URL_SLP|$NEW_URL_SLP|" $OSM_BRIGHT_MML

    URL_LPS="\"file\": \"http://data.openstreetmapdata.com/land-polygons-split-3857.zip\""
    NEW_URL_LPS="\"file\": \"/usr/local/share/maps/style/osm-bright-master/shp/land-polygons-split-3857/land_polygons.shp\", \"type\": \"shape\""
    sudo -u $LINUX_USER sed -in "s|$URL_LPS|$NEW_URL_LPS|" $OSM_BRIGHT_MML

    URL_PPS="\"file\": \"http://mapbox-geodata.s3.amazonaws.com/natural-earth-1.4.0/cultural/10m-populated-places-simple.zip\""
    NEW_URL_PPS="\"file\": \"/usr/local/share/maps/style/osm-bright-master/shp/ne_10m_populated_places_simple/ne_10m_populated_places_simple.shp\", \"type\": \"shape\""
    sudo -u $LINUX_USER sed -in "s|$URL_PPS|$NEW_URL_PPS|" $OSM_BRIGHT_MML

    # to replace srs and srs-name with unique line
    SOURCE="\"srs\": \"\","
    sudo -u $LINUX_USER sed -in "s|$SOURCE||" $OSM_BRIGHT_MML
    SOURCE_NAME="\"srs-name\": \"autodetect\""
    NEW_SOURCE_NAME="\"srs\": \"+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs\""
    sudo -u $LINUX_USER sed -in "s|$SOURCE_NAME|$NEW_SOURCE_NAME|" $OSM_BRIGHT_MML

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

    MODTILE_OPTS="\n\n    LoadTileConfigFile $PATH_RENDERD_FILE\n    ModTileRenderdSocketName /var/run/renderd/renderd.sock\n    # Timeout before giving up for a tile to be rendered\n    ModTileRequestTimeout 0\n    # Timeout before giving up for a tile to be rendered that is otherwise missing\n    ModTileMissingRequestTimeout 30\n\n"
    
    sudo sed -in "s|</VirtualHost>|$MODTILE_OPTS</VirtualHost>|" $APACHE_CONF_FILE

    # restart apache
    sudo a2enconf mod_tile
    sudo service apache2 reload
fi

if $STEP_12; then
    echo "PASO 12 ========================================================"
    POSTGRES_CONF=/etc/postgresql/9.3/main/postgresql.conf
    
    #shared_buffers = 128MB

    OLD_CHECKPOINT_SEGMENTS="#checkpoint_segments = 3"
    NEW_CHECKPOINT_SEGMENTS="checkpoint_segments = 20"
    sudo sed -in "s|$OLD_CHECKPOINT_SEGMENTS|$NEW_CHECKPOINT_SEGMENTS|" $POSTGRES_CONF

    # maintenance work mem
    OLD_MWM="#maintenance_work_mem = 16MB"
    NEW_MWM="maintenance_work_mem = 256MB"
    sudo sed -in "s|$OLD_MWM|$NEW_MWM|" $POSTGRES_CONF

    OLD_AUTOVACUUM="#autovacuum = on"
    NEW_AUTOVACUUM="autovacuum = off"
    sudo sed -in "s|$OLD_AUTOVACUUM|$NEW_AUTOVACUUM|" $POSTGRES_CONF

    # set kernel 
    SYSCTL_PATH=/etc/sysctl.conf

    SYSCTL_SET="\n# Tile Server\n# Increase kernel shared memory segments - needed for large databases\nkernel.shmmax=268435456"
    #no funciona!!!!
    sudo sed -in "$ a\ $SYSCTL_SET" $SYSCTL_PATH

    # reboot the computer
    read -p "it is necessary reboot server. After verify the change with 'sudo sysctl kernel.shmmax'. You should see '268435456'\n" -n 1 -s
    #sudo sysctl kernel.shmmax
fi

# End of the first stage. Now you have to reboot the computer and then execute the second stage
#read -p "End of the first stage. Now you have to reboot the computer and then execute the second stage\n" -n 1 -s
#exit

if $STEP_13; then
    echo "PASO 13 ========================================================"

    DATA_PATH=/usr/local/share/maps/planet
    sudo mkdir $DATA_PATH
    sudo chown $LINUX_USER $DATA_PATH
    cd $DATA_PATH

    # get Chile data
    sudo -u $LINUX_USER wget http://download.geofabrik.de/south-america/chile-latest.osm.pbf

    # importing data to postgres
    # if you get the error "Out of memory for dense node cache, reduce --cache size" modify --cache option
    sudo -u $LINUX_USER osm2pgsql --slim -d $POSTGRES_DBNAME -C 16000 --number-processes 3 --cache 700 $DATA_PATH/chile-latest.osm.pbf
fi

# turn on server
if $STEP_14; then
    echo "PASO 14 ========================================================"

    sudo service apache2 reload

    sudo ln -s $INSTALL_DIRECTORY/test_tile_server.html test_tile_server.html

    sudo -u $LINUX_USER  renderd -f -c /usr/local/etc/renderd.conf

    # now, try http://localhost/test_tile_server.html
fi

# setting renderd to run automatically 
if $STEP_15; then
    echo "PASO 15 ========================================================"

    RENDERD_INIT_FILE=/etc/init.d/renderd
    sudo cp $PATH_SRC/mod_tile/debian/renderd.init $RENDERD_INIT_FILE
    sudo chmod a+x $RENDERD_INIT_FILE

    sudo sed -in 's|DAEMON=/usr/bin/\$NAME|DAEMON=/usr/local/bin/\$NAME|' $RENDERD_INIT_FILE
    sudo sed -in 's|DAEMON_ARGS=""|DAEMON_ARGS="-c /usr/local/etc/renderd.conf"|' $RENDERD_INIT_FILE
    sudo sed -in "s|RUNASUSER=www-data|RUNASUSER=$LINUX_USER|" $RENDERD_INIT_FILE

    # You should now be able to start mapnik by doing the following:
    # sudo /etc/init.d/renderd start
    # and stop it:
    # sudo /etc/init.d/renderd stop

    # link to start automatically
    sudo ln -s $RENDERD_INIT_FILE /etc/rc2.d/S20renderd

    sudo service apache2 reload
fi
