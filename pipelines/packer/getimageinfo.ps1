$Publisher = "MicrosoftWindowsDesktop" #  (Get-AzVMImagePublisher -Location $location |  Out-GridView -PassThru).PublisherName 
$Location = 'northeurope'
$ImageOffer = Get-AzVMImageOffer -Location $Location  -PublisherName $Publisher | Out-GridView -PassThru # watchout for 'office-365' or 'Windows-10'
$PublisherOffer = Get-AzVMImageOffer -Location $Location -PublisherName $Publisher | where Offer -EQ "office-365" # $ImageOffer.Offer
    
(Get-AzVMImageSku -Location $Location -PublisherName $PublisherOffer.PublisherName -Offer $PublisherOffer.Offer).Skus | Out-GridView -PassThru

#e.g. '21h1-evd-o365pp' for office
   