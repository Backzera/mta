function replaceModel() 
  txd = engineLoadTXD("ak47.txd", 355 )
  engineImportTXD(txd, 355)
  dff = engineLoadDFF("ak47.dff", 355 )
  engineReplaceModel(dff, 355)

  txd = engineLoadTXD("desert_eagle.txd", 348 )
  engineImportTXD(txd, 348)
  dff = engineLoadDFF("desert_eagle.dff", 348 )
  engineReplaceModel(dff, 348)

  txd = engineLoadTXD("grenade.txd", 342 )
  engineImportTXD(txd, 342)
  dff = engineLoadDFF("grenade.dff", 342 )
  engineReplaceModel(dff, 342)


  txd = engineLoadTXD("knifecur.txd", 335 )
  engineImportTXD(txd, 335)
  dff = engineLoadDFF("knifecur.dff", 335 )
  engineReplaceModel(dff, 335)


  txd = engineLoadTXD("m4.txd", 356 )
  engineImportTXD(txd, 356)
  dff = engineLoadDFF("m4.dff", 356 )
  engineReplaceModel(dff, 356)

  txd = engineLoadTXD("mp5lng.txd", 353 )
  engineImportTXD(txd, 353)
  dff = engineLoadDFF("mp5lng.dff", 353 )
  engineReplaceModel(dff, 353)


  txd = engineLoadTXD("silenced.txd", 347 )
  engineImportTXD(txd, 347)
  dff = engineLoadDFF("silenced.dff", 347 )
  engineReplaceModel(dff, 347)

  txd = engineLoadTXD("sniper.txd", 358 )
  engineImportTXD(txd, 358)
  dff = engineLoadDFF("sniper.dff", 358 )
  engineReplaceModel(dff, 358)

  txd = engineLoadTXD("shotgspa.txd", 349 )
  engineImportTXD(txd, 349)
  dff = engineLoadDFF("shotgspa.dff", 349 )
  engineReplaceModel(dff, 349)

end
addEventHandler ( "onClientResourceStart", getResourceRootElement(getThisResource()), replaceModel)