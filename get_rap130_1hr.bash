#!/bin/bash

## script that will generate an event-centered composite from RAP analyses, using only command-line tools!
##  Russ Schumacher, January 2017

## in particular, it will do the following:
##  1) read in a text file with a list of dates, times, and locations, representing cases the user is interested in
##  2) get a RAP-130 (13-km grid) file for that time, using fast GRIB downloading to get only desired fields
##  3) subset the RAP grids to an NxN grid, centered on the centerpoint of the event 
##  4) average these grids together, generating a storm-centered composite!
##  5) output a netCDF file of the composite 

###  needed software (beyond your unix terminal and shell):
##  a) wgrib2 (http://www.cpc.ncep.noaa.gov/products/wesley/wgrib2/) 
##  b) perl (should be installed by default on any unix system)
##  c) cURL (for downloading files)
##  d) NCO (netCDF operators)  (nco.sourceforge.net) 
##  e) ncview (optional; for a quick look at your netcdf file): (meteora.ucsd.edu/~pierce/ncview_home_page.html)

## all of these are open-source codes, that can be installed easily with your system's package manager (yum, macports, homebrew, etc.) 

#set -x  ## this gives you very verbose output if you turn it on

## here, specify the file that has the list of cases you're interested in compositing.
##  In this example, columns need to be: year, month, date, hour, longitude, latitude
##  See "example_event_list.txt" for the needed format
export textfile='example_event_list.txt'

####### user shouldn't need to change anything below here.

## find how many points there are
export numpts=`wc -l $textfile | awk '{print $1}'`  ## awk is nice for parsing data with columns 
echo "number of points: " $numpts

rm -f *_small.nc  ## remove any leftover .nc files so we're starting fresh

## loop over all of those points
index=1
while [ $index -le $numpts ] ; do

## pull in the date and time from the text listing of the events
year=`awk 'NR=='$index' {print $1}' $textfile` 
month=`awk 'NR=='$index' {print $2}' $textfile` 
day=`awk 'NR=='$index' {print $3}' $textfile` 
maxhr=`awk 'NR=='$index' {print $4}' $textfile` 
lon=`awk 'NR=='$index' {print $5}' $textfile`
lat=`awk 'NR=='$index' {print $6}' $textfile`

year=`printf %04d $year`  ## printf will re-format your numbers into 4 digits (or 2 digits, etc.)
month=`printf %02d $month`
day=`printf %02d $day`
maxhr=`printf %02d $maxhr`

## first, download a small RAP file with a single field (500-mb height) to get the location of the center, etc.
## this uses the fast downloading perl script, from here; with just slight modification to point to RAP files
#http://www.cpc.ncep.noaa.gov/products/wesley/get_gfs.html
./get_rap_130.pl data ${year}${month}${day}${maxhr} 0 0 0 HGT 500_mb . 

## get the x-y points of the center 
 wgrib2 rap_130_${year}${month}${day}_${maxhr}00_000.grb2 -v -d 1 -lon $lon $lat > data2.txt  ## writes the lat/lon/index to a file
 dum2=`awk '{print match($0,"ix=")}' "data2.txt" | awk '{print $1}'`  ## this finds where the 'ix=' text is in the file
 dum2=$((10#$dum2 + 3))
 xpoint=`awk '{print substr($0,'$dum2',3)}' "data2.txt"` ## this is the x-index
 dum3=`awk '{print match($0,"iy=")}' "data2.txt" | awk '{print $1}'`  ## this finds where the 'iy=' text is in the file
 dum3=$((10#$dum3 + 3))
 ypoint=`awk '{print substr($0,'$dum3',3)}' "data2.txt"` ## this is the y-index
# conditional for if the x or y points are less than three digits:
  if [ ${xpoint:2:1} == "," ]; then
   xpoint=${xpoint:0:2}
  fi
  if [ ${ypoint:2:1} == "," ]; then
   ypoint=${ypoint:0:2}
  fi
echo "centerpoint (x,y) is: " $xpoint $ypoint

## create a 51x51 grid point box centered on ix and iy
imin=$((10#$xpoint - 25))
imax=$((10#$xpoint + 25))
jmin=$((10#$ypoint - 25))
jmax=$((10#$ypoint + 25))
echo "bounds of subset box are: " $imin $imax $jmin $jmax

## now, download the rap data for this time, using the fast download script to get just the fields we want
./get_rap_130.pl data ${year}${month}${day}${maxhr} 0 0 0 hgt:ugrd:vgrd:pwat:tmp:rh:mslma:cape:hlcy 250_mb:300_mb:400_mb:500_mb:600_mb:700_mb:750_mb:800_mb:850_mb:900_mb:925_mb:950_mb:1000_mb:entire_atmosphere:mean_sea_level:1000-0_m:255-0_mb .  

## and convert the rap to netcdf and subset the data down to the regional domain, centered on ix,iy

### NCL method (more efficient)
#ncl_convert2nc rap_130_${year}${month}${day}_${maxhr}00_000.grb2
#ncks -O -F -d xgrid_0,$imin,$imax -d ygrid_0,$jmin,$jmax rap_130_${year}${month}${day}_${maxhr}00_000.nc rap_130_${year}${month}${day}_${maxhr}00_000_small.nc

### wgrib2 method (doesn't require NCL!)
wgrib2 rap_130_${year}${month}${day}_${maxhr}00_000.grb2 -netcdf rap_130_${year}${month}${day}_${maxhr}00_000.nc
ncks -O -F -d x,$imin,$imax -d y,$jmin,$jmax rap_130_${year}${month}${day}_${maxhr}00_000.nc rap_130_${year}${month}${day}_${maxhr}00_000_small.nc

#rm rap_130_${year}${month}${day}_${maxhr}00_000.nc

index=$((10#$index + 1))  ## move on to next file...
done

## create a composite of all the files we have.
echo "calculating composite"
ls *_small.nc > filelist.txt
more filelist.txt | ncea -O -o composite.nc

## if you want to clean up the directory by removing all the original grib files:
#rm -f rap130*.grb


