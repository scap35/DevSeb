#/usr/bin/ruby
# ------------------------------------------------------------------------------------
# Auteur : S. Caprais
# Date   : 26/06/2014
# Description :
# lire le fichier MatrixRelease, onglet VHM
# - affiche les doublons de la colonne R (17)
# ------------------------------------------------------------------------------------

require 'nokogiri'
require 'spreadsheet'
require 'csv2other'
require 'csv'

if ARGV.count < 1
  puts "I need at least 1 parameter:"
  puts "#{__FILE__} <matrixRelease.xls>"
  exit
end


book = Spreadsheet.open(ARGV[0]) 
ligne = 0
indice = 0
listeR = []
etat = Hash.new(0)
book.worksheet('Catalogue VHM').each do |row|
  ligne = ligne + 1
  if (ligne == 4)
    #puts row.join(',')
	entete = row
  else
	 if (row[2] != 'Obsolete')
		listeR[indice] = row[17] 
		etat{row17]] = row[2]
	end
	 indice += 1
  end
  # interruption de la lecture du fichier Excel (pour test)
  # break if ligne == 6
end
puts "nombre d'elements de la liste:"
puts listeR.length


b = Hash.new(0)

# iterate over the array, counting duplicate entries
listeR.each do |v|
  b[v] += 1
end

b.each do |k, v|
	if (v > 1)
		puts "#{k} appears #{v} times"
		# listeR.each do |w|
			# puts 
	end	
end