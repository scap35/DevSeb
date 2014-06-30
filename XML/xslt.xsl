<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:template match="/">
  <html>
    <head>
      <title>Exemple de sortie HTML</title>
      <meta http-equiv="Content-Type" content="text/html; charset=ISO-8859-1" />
    </head>
    <body>
      <h1>Bouteille de marque <xsl:value-of select="bouteille/marque" /></h1>
      <h2>Composition:</h2>
      <h3>Ions positifs</h3>
      <ul>
        <xsl:for-each select="bouteille/composition/ion_positif">
          <xsl:value-of select="." />
        </xsl:for-each>
      </ul>
      <h3>Ions négatifs</h3>
      <ul>
        <xsl:for-each select="bouteille/composition/ion_negatif">
          <li><xsl:value-of select="." /></li>
        </xsl:for-each>
      </ul>
      <h3>Autres matériaux</h3>
      <ul>
        <xsl:for-each select="//autres_materiaux">
          <li><xsl:value-of select="." /></li>
        </xsl:for-each>
      </ul>
<h2>Lieu d'origine</h2>
      <p>Ville de <b><xsl:value-of select="bouteille/source/ville" /></b>, dans le département <b><xsl:value-of select="bouteille/source/departement" /></b></p>
      <h2>Autres informations</h2>
      <ul>
        <li>Contenance: <xsl:value-of select="bouteille/contenance" /></li>
        <li>pH: <xsl:value-of select="bouteille/ph" /></li>
      </ul>
    </body>
  </html>
</xsl:template>
</xsl:stylesheet>