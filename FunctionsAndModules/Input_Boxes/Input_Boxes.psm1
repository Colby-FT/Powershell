Function Invoke-9InpBox
{
	<#
	.SYNOPSIS
	Generate a customized form with nine(9) user input boxes.
	
	.DESCRIPTION
	Generate a customized form with nine(9) user input boxes.
	
	For a different number of input boxes try Invoke-1InpBox, Invoke-2InpBox, Invoke-3InpBox, etc
	
	.PARAMETER formTitle 
	The title that will appear at the top of the form.
	.PARAMETER formPrompt
	The message to the user.
	.PARAMETER b1Text
	The text that will show to the left of each input box.
		
	.EXAMPLE
	Invoke-2InpBox -formTitle "Input form title" -formPrompt "Please enter some info." -b1Text "Info here:" -b2Text "Also Here:"
	
	This will create a user input form, and return all input values to the terminal.
	
	.EXAMPLE
	$UserInput = Invoke-2InpBox -formTitle "Input form title" -formPrompt "Please enter some info." -b1Text "Info here:" -b2Text "Also Here:"
	
	This will create a user input form, and return all input values to a PSObject. In this case $UserInput.
	The values can then be returned with:
	$UserInput
	$UserInput.Box1
	$UserInput.box2
	#>
	
	[CmdletBinding()]
	Param
	(
		[parameter(Mandatory=$true)]
		$formTitle,
		[parameter(Mandatory=$true)]
		$formPrompt,
		[parameter(Mandatory=$true)]
		$b1Text,
		[parameter(Mandatory=$true)]
		$b2Text,
		[parameter(Mandatory=$true)]
		$b3Text,
		[parameter(Mandatory=$true)]
		$b4Text,
		[parameter(Mandatory=$true)]
		$b5Text,
		[parameter(Mandatory=$true)]
		$b6Text,
		[parameter(Mandatory=$true)]
		$b7Text,
		[parameter(Mandatory=$true)]
		$b8Text,
		[parameter(Mandatory=$true)]
		$b9Text
	)
	
	[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
	[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
	
	$objForm = New-Object System.Windows.Forms.Form 
	$objForm.Text = $formTitle
	$objForm.Size = New-Object System.Drawing.Size(400,300) 
	$objForm.StartPosition = "CenterScreen"
	
	$objForm.KeyPreview = $True
	$objForm.Add_KeyDown({
		if ($_.KeyCode -eq "Enter")
		{
			$objForm.Close()
		}
		ELSEIF ($_.KeyCode -eq "Escape")
		{
			BREAK
		}
	})
	
	$OKButton = New-Object System.Windows.Forms.Button
	$OKButton.Location = New-Object System.Drawing.Size(105,225)
	$OKButton.Size = New-Object System.Drawing.Size(75,23)
	$OKButton.Text = "OK"
	$OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
	$objForm.AcceptButton = $OKButton
	$objForm.Controls.Add($OKButton)
	
	$CancelButton = New-Object System.Windows.Forms.Button
	$CancelButton.Location = New-Object System.Drawing.Size(180,225)
	$CancelButton.Size = New-Object System.Drawing.Size(75,23)
	$CancelButton.Text = "Cancel"
	$CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
	$objForm.CancelButton = $CancelButton
	$objForm.Controls.Add($CancelButton)
	
	$objLabel = New-Object System.Windows.Forms.Label
	$objLabel.Location = New-Object System.Drawing.Size(20,20) 
	$objLabel.Size = New-Object System.Drawing.Size(380,20) 
	$objLabel.Text = $formPrompt
	$objForm.Controls.Add($objLabel)
	
	$box1Name = New-Object System.Windows.Forms.Label
	$box1Name.Location = New-Object System.Drawing.Size(10,40) 
	$box1Name.Size = New-Object System.Drawing.Size(80,20) 
	$box1Name.Text = $b1Text
	$objForm.Controls.Add($box1Name)

	$box1 = New-Object System.Windows.Forms.TextBox
	$box1.Location = New-Object System.Drawing.Size(90,40) 
	$box1.Size = New-Object System.Drawing.Size(280,15) 
	$objForm.Controls.Add($box1)	
	
	$box2Name = New-Object System.Windows.Forms.Label
	$box2Name.Location = New-Object System.Drawing.Size(10,60) 
	$box2Name.Size = New-Object System.Drawing.Size(80,20) 
	$box2Name.Text = $b2Text
	$objForm.Controls.Add($box2Name) 
	
	$box2 = New-Object System.Windows.Forms.TextBox
	$box2.Location = New-Object System.Drawing.Size(90,60) 
	$box2.Size = New-Object System.Drawing.Size(280,15) 
	$objForm.Controls.Add($box2) 
	
	$box3Name = New-Object System.Windows.Forms.Label
	$box3Name.Location = New-Object System.Drawing.Size(10,80) 
	$box3Name.Size = New-Object System.Drawing.Size(80,20) 
	$box3Name.Text = $b3Text
	$objForm.Controls.Add($box3Name)
	
	$box3 = New-Object System.Windows.Forms.TextBox 
	$box3.Location = New-Object System.Drawing.Size(90,80) 
	$box3.Size = New-Object System.Drawing.Size(280,20) 
	$objForm.Controls.Add($box3) 
	
	$box4Name = New-Object System.Windows.Forms.Label
	$box4Name.Location = New-Object System.Drawing.Size(10,100) 
	$box4Name.Size = New-Object System.Drawing.Size(80,20) 
	$box4Name.Text = $b4Text
	$objForm.Controls.Add($box4Name)
	
	$box4 = New-Object System.Windows.Forms.TextBox 
	$box4.Location = New-Object System.Drawing.Size(90,100) 
	$box4.Size = New-Object System.Drawing.Size(280,20) 
	$objForm.Controls.Add($box4) 
	
	$box5Name = New-Object System.Windows.Forms.Label
	$box5Name.Location = New-Object System.Drawing.Size(10,120) 
	$box5Name.Size = New-Object System.Drawing.Size(80,20) 
	$box5Name.Text = $b5Text
	$objForm.Controls.Add($box5Name)
	
	$box5 = New-Object System.Windows.Forms.TextBox 
	$box5.Location = New-Object System.Drawing.Size(90,120) 
	$box5.Size = New-Object System.Drawing.Size(280,20) 
	$objForm.Controls.Add($box5) 
	
	$box6Name = New-Object System.Windows.Forms.Label
	$box6Name.Location = New-Object System.Drawing.Size(10,140) 
	$box6Name.Size = New-Object System.Drawing.Size(80,20) 
	$box6Name.Text = $b6Text
	$objForm.Controls.Add($box6Name)
	
	$box6 = New-Object System.Windows.Forms.TextBox 
	$box6.Location = New-Object System.Drawing.Size(90,140) 
	$box6.Size = New-Object System.Drawing.Size(280,20) 
	$objForm.Controls.Add($box6) 
	
	$box7Name = New-Object System.Windows.Forms.Label
	$box7Name.Location = New-Object System.Drawing.Size(10,160) 
	$box7Name.Size = New-Object System.Drawing.Size(80,20) 
	$box7Name.Text = $b7Text
	$objForm.Controls.Add($box7Name)
	
	$box7 = New-Object System.Windows.Forms.TextBox 
	$box7.Location = New-Object System.Drawing.Size(90,160) 
	$box7.Size = New-Object System.Drawing.Size(280,20) 
	$objForm.Controls.Add($box7) 
	
	$box8Name = New-Object System.Windows.Forms.Label
	$box8Name.Location = New-Object System.Drawing.Size(10,180) 
	$box8Name.Size = New-Object System.Drawing.Size(80,20) 
	$box8Name.Text = $b8Text
	$objForm.Controls.Add($box8Name)
	
	$box8 = New-Object System.Windows.Forms.TextBox 
	$box8.Location = New-Object System.Drawing.Size(90,180) 
	$box8.Size = New-Object System.Drawing.Size(280,20) 
	$objForm.Controls.Add($box8) 
	
	$box9Name = New-Object System.Windows.Forms.Label
	$box9Name.Location = New-Object System.Drawing.Size(10,200) 
	$box9Name.Size = New-Object System.Drawing.Size(80,20)
	$box9Name.Text = $b9Text
	$objForm.Controls.Add($box9Name)
	
	$box9 = New-Object System.Windows.Forms.TextBox
	$box9.Location = New-Object System.Drawing.Size(90,200) 
	$box9.Size = New-Object System.Drawing.Size(280,20) 
	$objForm.Controls.Add($box9)
	
	$objForm.Topmost = $True
	
	$objForm.Add_Shown({$objForm.Activate(); $box1.focus()})
	$formResult = $objForm.ShowDialog()
	
	IF ($formResult -eq [System.Windows.Forms.DialogResult]::Cancel)
	{
	BREAK
	}

	$Returns = @{
		'Box1' = $box1.text
		'Box2' = $box2.text
		'Box3' = $box3.text
		'Box4' = $box4.text
		'Box5' = $box5.text
		'Box6' = $box6.text
		'Box7' = $box7.text
		'Box8' = $box8.text
		'Box9' = $box9.text
	}
	$Returns = [PSObject]$Returns
	$Returns
}

Function Invoke-8InpBox
{
	<#
	.SYNOPSIS
	Generate a customized form with eight(8) user input boxes.
	
	.DESCRIPTION
	Generate a customized form with eight(8) user input boxes.
	
	For a different number of input boxes try Invoke-1InpBox, Invoke-2InpBox, Invoke-3InpBox, etc
	
	.PARAMETER formTitle 
	The title that will appear at the top of the form.
	.PARAMETER formPrompt
	The message to the user.
	.PARAMETER b1Text
	The text that will show to the left of each input box.
		
	.EXAMPLE
	Invoke-2InpBox -formTitle "Input form title" -formPrompt "Please enter some info." -b1Text "Info here:" -b2Text "Also Here:"
	
	This will create a user input form, and return all input values to the terminal.
	
	.EXAMPLE
	$UserInput = Invoke-2InpBox -formTitle "Input form title" -formPrompt "Please enter some info." -b1Text "Info here:" -b2Text "Also Here:"
	
	This will create a user input form, and return all input values to a PSObject. In this case $UserInput.
	The values can then be returned with:
	$UserInput
	$UserInput.Box1
	$UserInput.box2
	#>
	
	[CmdletBinding()]
	Param
	(
		[parameter(Mandatory=$true)]
		$formTitle,
		[parameter(Mandatory=$true)]
		$formPrompt,
		[parameter(Mandatory=$true)]
		$b1Text,
		[parameter(Mandatory=$true)]
		$b2Text,
		[parameter(Mandatory=$true)]
		$b3Text,
		[parameter(Mandatory=$true)]
		$b4Text,
		[parameter(Mandatory=$true)]
		$b5Text,
		[parameter(Mandatory=$true)]
		$b6Text,
		[parameter(Mandatory=$true)]
		$b7Text,
		[parameter(Mandatory=$true)]
		$b8Text
	)
	
	[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
	[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
	
	$objForm = New-Object System.Windows.Forms.Form 
	$objForm.Text = $formTitle
	$objForm.Size = New-Object System.Drawing.Size(400,280) 
	$objForm.StartPosition = "CenterScreen"
	
	$objForm.KeyPreview = $True
	$objForm.Add_KeyDown({
		if ($_.KeyCode -eq "Enter")
		{
			$objForm.Close()
		}
		ELSEIF ($_.KeyCode -eq "Escape")
		{
			BREAK
		}
	})
	
	$OKButton = New-Object System.Windows.Forms.Button
	$OKButton.Location = New-Object System.Drawing.Size(105,205)
	$OKButton.Size = New-Object System.Drawing.Size(75,23)
	$OKButton.Text = "OK"
	$OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
	$objForm.AcceptButton = $OKButton
	$objForm.Controls.Add($OKButton)
	
	$CancelButton = New-Object System.Windows.Forms.Button
	$CancelButton.Location = New-Object System.Drawing.Size(180,205)
	$CancelButton.Size = New-Object System.Drawing.Size(75,23)
	$CancelButton.Text = "Cancel"
	$CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
	$objForm.CancelButton = $CancelButton
	$objForm.Controls.Add($CancelButton)
	
	$objLabel = New-Object System.Windows.Forms.Label
	$objLabel.Location = New-Object System.Drawing.Size(20,20) 
	$objLabel.Size = New-Object System.Drawing.Size(380,20) 
	$objLabel.Text = $formPrompt
	$objForm.Controls.Add($objLabel)
	
	$box1Name = New-Object System.Windows.Forms.Label
	$box1Name.Location = New-Object System.Drawing.Size(10,40) 
	$box1Name.Size = New-Object System.Drawing.Size(80,20) 
	$box1Name.Text = $b1Text
	$objForm.Controls.Add($box1Name)

	$box1 = New-Object System.Windows.Forms.TextBox
	$box1.Location = New-Object System.Drawing.Size(90,40) 
	$box1.Size = New-Object System.Drawing.Size(280,15) 
	$objForm.Controls.Add($box1)	
	
	$box2Name = New-Object System.Windows.Forms.Label
	$box2Name.Location = New-Object System.Drawing.Size(10,60) 
	$box2Name.Size = New-Object System.Drawing.Size(80,20) 
	$box2Name.Text = $b2Text
	$objForm.Controls.Add($box2Name) 
	
	$box2 = New-Object System.Windows.Forms.TextBox
	$box2.Location = New-Object System.Drawing.Size(90,60) 
	$box2.Size = New-Object System.Drawing.Size(280,15) 
	$objForm.Controls.Add($box2) 
	
	$box3Name = New-Object System.Windows.Forms.Label
	$box3Name.Location = New-Object System.Drawing.Size(10,80) 
	$box3Name.Size = New-Object System.Drawing.Size(80,20) 
	$box3Name.Text = $b3Text
	$objForm.Controls.Add($box3Name)
	
	$box3 = New-Object System.Windows.Forms.TextBox 
	$box3.Location = New-Object System.Drawing.Size(90,80) 
	$box3.Size = New-Object System.Drawing.Size(280,20) 
	$objForm.Controls.Add($box3) 
	
	$box4Name = New-Object System.Windows.Forms.Label
	$box4Name.Location = New-Object System.Drawing.Size(10,100) 
	$box4Name.Size = New-Object System.Drawing.Size(80,20) 
	$box4Name.Text = $b4Text
	$objForm.Controls.Add($box4Name)
	
	$box4 = New-Object System.Windows.Forms.TextBox 
	$box4.Location = New-Object System.Drawing.Size(90,100) 
	$box4.Size = New-Object System.Drawing.Size(280,20) 
	$objForm.Controls.Add($box4) 
	
	$box5Name = New-Object System.Windows.Forms.Label
	$box5Name.Location = New-Object System.Drawing.Size(10,120) 
	$box5Name.Size = New-Object System.Drawing.Size(80,20) 
	$box5Name.Text = $b5Text
	$objForm.Controls.Add($box5Name)
	
	$box5 = New-Object System.Windows.Forms.TextBox 
	$box5.Location = New-Object System.Drawing.Size(90,120) 
	$box5.Size = New-Object System.Drawing.Size(280,20) 
	$objForm.Controls.Add($box5) 
	
	$box6Name = New-Object System.Windows.Forms.Label
	$box6Name.Location = New-Object System.Drawing.Size(10,140) 
	$box6Name.Size = New-Object System.Drawing.Size(80,20) 
	$box6Name.Text = $b6Text
	$objForm.Controls.Add($box6Name)
	
	$box6 = New-Object System.Windows.Forms.TextBox 
	$box6.Location = New-Object System.Drawing.Size(90,140) 
	$box6.Size = New-Object System.Drawing.Size(280,20) 
	$objForm.Controls.Add($box6) 
	
	$box7Name = New-Object System.Windows.Forms.Label
	$box7Name.Location = New-Object System.Drawing.Size(10,160) 
	$box7Name.Size = New-Object System.Drawing.Size(80,20) 
	$box7Name.Text = $b7Text
	$objForm.Controls.Add($box7Name)
	
	$box7 = New-Object System.Windows.Forms.TextBox 
	$box7.Location = New-Object System.Drawing.Size(90,160) 
	$box7.Size = New-Object System.Drawing.Size(280,20) 
	$objForm.Controls.Add($box7) 
	
	$box8Name = New-Object System.Windows.Forms.Label
	$box8Name.Location = New-Object System.Drawing.Size(10,180) 
	$box8Name.Size = New-Object System.Drawing.Size(80,20) 
	$box8Name.Text = $b8Text
	$objForm.Controls.Add($box8Name)
	
	$box8 = New-Object System.Windows.Forms.TextBox 
	$box8.Location = New-Object System.Drawing.Size(90,180) 
	$box8.Size = New-Object System.Drawing.Size(280,20) 
	$objForm.Controls.Add($box8) 

	$objForm.Topmost = $True
	
	$objForm.Add_Shown({$objForm.Activate(); $box1.focus()})
	$formResult = $objForm.ShowDialog()
	
	IF ($formResult -eq [System.Windows.Forms.DialogResult]::Cancel)
	{
	BREAK
	}

	$Returns = @{
		'Box1' = $box1.text
		'Box2' = $box2.text
		'Box3' = $box3.text
		'Box4' = $box4.text
		'Box5' = $box5.text
		'Box6' = $box6.text
		'Box7' = $box7.text
		'Box8' = $box8.text
	}
	$Returns = [PSObject]$Returns
	$Returns
}

Function Invoke-7InpBox
{
	<#
	.SYNOPSIS
	Generate a customized form with seven(7) user input boxes.
	
	.DESCRIPTION
	Generate a customized form with seven(7) user input boxes.
	
	For a different number of input boxes try Invoke-1InpBox, Invoke-2InpBox, Invoke-3InpBox, etc
	
	.PARAMETER formTitle 
	The title that will appear at the top of the form.
	.PARAMETER formPrompt
	The message to the user.
	.PARAMETER b1Text
	The text that will show to the left of each input box.
		
	.EXAMPLE
	Invoke-2InpBox -formTitle "Input form title" -formPrompt "Please enter some info." -b1Text "Info here:" -b2Text "Also Here:"
	
	This will create a user input form, and return all input values to the terminal.
	
	.EXAMPLE
	$UserInput = Invoke-2InpBox -formTitle "Input form title" -formPrompt "Please enter some info." -b1Text "Info here:" -b2Text "Also Here:"
	
	This will create a user input form, and return all input values to a PSObject. In this case $UserInput.
	The values can then be returned with:
	$UserInput
	$UserInput.Box1
	$UserInput.box2
	#>
	
	[CmdletBinding()]
	Param
	(
		[parameter(Mandatory=$true)]
		$formTitle,
		[parameter(Mandatory=$true)]
		$formPrompt,
		[parameter(Mandatory=$true)]
		$b1Text,
		[parameter(Mandatory=$true)]
		$b2Text,
		[parameter(Mandatory=$true)]
		$b3Text,
		[parameter(Mandatory=$true)]
		$b4Text,
		[parameter(Mandatory=$true)]
		$b5Text,
		[parameter(Mandatory=$true)]
		$b6Text,
		[parameter(Mandatory=$true)]
		$b7Text
	)
	
	[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
	[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
	
	$objForm = New-Object System.Windows.Forms.Form 
	$objForm.Text = $formTitle
	$objForm.Size = New-Object System.Drawing.Size(400,260) 
	$objForm.StartPosition = "CenterScreen"
	
	$objForm.KeyPreview = $True
	$objForm.Add_KeyDown({
		if ($_.KeyCode -eq "Enter")
		{
			$objForm.Close()
		}
		ELSEIF ($_.KeyCode -eq "Escape")
		{
			BREAK
		}
	})
	
	$OKButton = New-Object System.Windows.Forms.Button
	$OKButton.Location = New-Object System.Drawing.Size(105,185)
	$OKButton.Size = New-Object System.Drawing.Size(75,23)
	$OKButton.Text = "OK"
	$OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
	$objForm.AcceptButton = $OKButton
	$objForm.Controls.Add($OKButton)
	
	$CancelButton = New-Object System.Windows.Forms.Button
	$CancelButton.Location = New-Object System.Drawing.Size(180,185)
	$CancelButton.Size = New-Object System.Drawing.Size(75,23)
	$CancelButton.Text = "Cancel"
	$CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
	$objForm.CancelButton = $CancelButton
	$objForm.Controls.Add($CancelButton)
	
	$objLabel = New-Object System.Windows.Forms.Label
	$objLabel.Location = New-Object System.Drawing.Size(20,20) 
	$objLabel.Size = New-Object System.Drawing.Size(380,20) 
	$objLabel.Text = $formPrompt
	$objForm.Controls.Add($objLabel)
	
	$box1Name = New-Object System.Windows.Forms.Label
	$box1Name.Location = New-Object System.Drawing.Size(10,40) 
	$box1Name.Size = New-Object System.Drawing.Size(80,20) 
	$box1Name.Text = $b1Text
	$objForm.Controls.Add($box1Name)

	$box1 = New-Object System.Windows.Forms.TextBox
	$box1.Location = New-Object System.Drawing.Size(90,40) 
	$box1.Size = New-Object System.Drawing.Size(280,15) 
	$objForm.Controls.Add($box1)	
	
	$box2Name = New-Object System.Windows.Forms.Label
	$box2Name.Location = New-Object System.Drawing.Size(10,60) 
	$box2Name.Size = New-Object System.Drawing.Size(80,20) 
	$box2Name.Text = $b2Text
	$objForm.Controls.Add($box2Name) 
	
	$box2 = New-Object System.Windows.Forms.TextBox
	$box2.Location = New-Object System.Drawing.Size(90,60) 
	$box2.Size = New-Object System.Drawing.Size(280,15) 
	$objForm.Controls.Add($box2) 
	
	$box3Name = New-Object System.Windows.Forms.Label
	$box3Name.Location = New-Object System.Drawing.Size(10,80) 
	$box3Name.Size = New-Object System.Drawing.Size(80,20) 
	$box3Name.Text = $b3Text
	$objForm.Controls.Add($box3Name)
	
	$box3 = New-Object System.Windows.Forms.TextBox 
	$box3.Location = New-Object System.Drawing.Size(90,80) 
	$box3.Size = New-Object System.Drawing.Size(280,20) 
	$objForm.Controls.Add($box3) 
	
	$box4Name = New-Object System.Windows.Forms.Label
	$box4Name.Location = New-Object System.Drawing.Size(10,100) 
	$box4Name.Size = New-Object System.Drawing.Size(80,20) 
	$box4Name.Text = $b4Text
	$objForm.Controls.Add($box4Name)
	
	$box4 = New-Object System.Windows.Forms.TextBox 
	$box4.Location = New-Object System.Drawing.Size(90,100) 
	$box4.Size = New-Object System.Drawing.Size(280,20) 
	$objForm.Controls.Add($box4) 
	
	$box5Name = New-Object System.Windows.Forms.Label
	$box5Name.Location = New-Object System.Drawing.Size(10,120) 
	$box5Name.Size = New-Object System.Drawing.Size(80,20) 
	$box5Name.Text = $b5Text
	$objForm.Controls.Add($box5Name)
	
	$box5 = New-Object System.Windows.Forms.TextBox 
	$box5.Location = New-Object System.Drawing.Size(90,120) 
	$box5.Size = New-Object System.Drawing.Size(280,20) 
	$objForm.Controls.Add($box5) 
	
	$box6Name = New-Object System.Windows.Forms.Label
	$box6Name.Location = New-Object System.Drawing.Size(10,140) 
	$box6Name.Size = New-Object System.Drawing.Size(80,20) 
	$box6Name.Text = $b6Text
	$objForm.Controls.Add($box6Name)
	
	$box6 = New-Object System.Windows.Forms.TextBox 
	$box6.Location = New-Object System.Drawing.Size(90,140) 
	$box6.Size = New-Object System.Drawing.Size(280,20) 
	$objForm.Controls.Add($box6) 
	
	$box7Name = New-Object System.Windows.Forms.Label
	$box7Name.Location = New-Object System.Drawing.Size(10,160) 
	$box7Name.Size = New-Object System.Drawing.Size(80,20) 
	$box7Name.Text = $b7Text
	$objForm.Controls.Add($box7Name)
	
	$box7 = New-Object System.Windows.Forms.TextBox 
	$box7.Location = New-Object System.Drawing.Size(90,160) 
	$box7.Size = New-Object System.Drawing.Size(280,20) 
	$objForm.Controls.Add($box7)
	
	$objForm.Topmost = $True
	
	$objForm.Add_Shown({$objForm.Activate(); $box1.focus()})
	$formResult = $objForm.ShowDialog()
	
	IF ($formResult -eq [System.Windows.Forms.DialogResult]::Cancel)
	{
	BREAK
	}

	$Returns = @{
		'Box1' = $box1.text
		'Box2' = $box2.text
		'Box3' = $box3.text
		'Box4' = $box4.text
		'Box5' = $box5.text
		'Box6' = $box6.text
		'Box7' = $box7.text
	}
	$Returns = [PSObject]$Returns
	$Returns
}

Function Invoke-6InpBox
{
	<#
	.SYNOPSIS
	Generate a customized form with six(6) user input boxes.
	
	.DESCRIPTION
	Generate a customized form with six(6) user input boxes.
	
	For a different number of input boxes try Invoke-1InpBox, Invoke-2InpBox, Invoke-3InpBox, etc
	
	.PARAMETER formTitle 
	The title that will appear at the top of the form.
	.PARAMETER formPrompt
	The message to the user.
	.PARAMETER b1Text
	The text that will show to the left of each input box.
		
	.EXAMPLE
	Invoke-2InpBox -formTitle "Input form title" -formPrompt "Please enter some info." -b1Text "Info here:" -b2Text "Also Here:"
	
	This will create a user input form, and return all input values to the terminal.
	
	.EXAMPLE
	$UserInput = Invoke-2InpBox -formTitle "Input form title" -formPrompt "Please enter some info." -b1Text "Info here:" -b2Text "Also Here:"
	
	This will create a user input form, and return all input values to a PSObject. In this case $UserInput.
	The values can then be returned with:
	$UserInput
	$UserInput.Box1
	$UserInput.box2
	#>
	
	[CmdletBinding()]
	Param
	(
		[parameter(Mandatory=$true)]
		$formTitle,
		[parameter(Mandatory=$true)]
		$formPrompt,
		[parameter(Mandatory=$true)]
		$b1Text,
		[parameter(Mandatory=$true)]
		$b2Text,
		[parameter(Mandatory=$true)]
		$b3Text,
		[parameter(Mandatory=$true)]
		$b4Text,
		[parameter(Mandatory=$true)]
		$b5Text,
		[parameter(Mandatory=$true)]
		$b6Text
	)
	
	[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
	[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
	
	$objForm = New-Object System.Windows.Forms.Form 
	$objForm.Text = $formTitle
	$objForm.Size = New-Object System.Drawing.Size(400,240) 
	$objForm.StartPosition = "CenterScreen"
	
	$objForm.KeyPreview = $True
	$objForm.Add_KeyDown({
		if ($_.KeyCode -eq "Enter")
		{
			$objForm.Close()
		}
		ELSEIF ($_.KeyCode -eq "Escape")
		{
			BREAK
		}
	})
	
	$OKButton = New-Object System.Windows.Forms.Button
	$OKButton.Location = New-Object System.Drawing.Size(105,165)
	$OKButton.Size = New-Object System.Drawing.Size(75,23)
	$OKButton.Text = "OK"
	$OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
	$objForm.AcceptButton = $OKButton
	$objForm.Controls.Add($OKButton)
	
	$CancelButton = New-Object System.Windows.Forms.Button
	$CancelButton.Location = New-Object System.Drawing.Size(180,165)
	$CancelButton.Size = New-Object System.Drawing.Size(75,23)
	$CancelButton.Text = "Cancel"
	$CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
	$objForm.CancelButton = $CancelButton
	$objForm.Controls.Add($CancelButton)
	
	$objLabel = New-Object System.Windows.Forms.Label
	$objLabel.Location = New-Object System.Drawing.Size(20,20) 
	$objLabel.Size = New-Object System.Drawing.Size(380,20) 
	$objLabel.Text = $formPrompt
	$objForm.Controls.Add($objLabel)
	
	$box1Name = New-Object System.Windows.Forms.Label
	$box1Name.Location = New-Object System.Drawing.Size(10,40) 
	$box1Name.Size = New-Object System.Drawing.Size(80,20) 
	$box1Name.Text = $b1Text
	$objForm.Controls.Add($box1Name)

	$box1 = New-Object System.Windows.Forms.TextBox
	$box1.Location = New-Object System.Drawing.Size(90,40) 
	$box1.Size = New-Object System.Drawing.Size(280,15) 
	$objForm.Controls.Add($box1)	
	
	$box2Name = New-Object System.Windows.Forms.Label
	$box2Name.Location = New-Object System.Drawing.Size(10,60) 
	$box2Name.Size = New-Object System.Drawing.Size(80,20) 
	$box2Name.Text = $b2Text
	$objForm.Controls.Add($box2Name) 
	
	$box2 = New-Object System.Windows.Forms.TextBox
	$box2.Location = New-Object System.Drawing.Size(90,60) 
	$box2.Size = New-Object System.Drawing.Size(280,15) 
	$objForm.Controls.Add($box2) 
	
	$box3Name = New-Object System.Windows.Forms.Label
	$box3Name.Location = New-Object System.Drawing.Size(10,80) 
	$box3Name.Size = New-Object System.Drawing.Size(80,20) 
	$box3Name.Text = $b3Text
	$objForm.Controls.Add($box3Name)
	
	$box3 = New-Object System.Windows.Forms.TextBox 
	$box3.Location = New-Object System.Drawing.Size(90,80) 
	$box3.Size = New-Object System.Drawing.Size(280,20) 
	$objForm.Controls.Add($box3) 
	
	$box4Name = New-Object System.Windows.Forms.Label
	$box4Name.Location = New-Object System.Drawing.Size(10,100) 
	$box4Name.Size = New-Object System.Drawing.Size(80,20) 
	$box4Name.Text = $b4Text
	$objForm.Controls.Add($box4Name)
	
	$box4 = New-Object System.Windows.Forms.TextBox 
	$box4.Location = New-Object System.Drawing.Size(90,100) 
	$box4.Size = New-Object System.Drawing.Size(280,20) 
	$objForm.Controls.Add($box4) 
	
	$box5Name = New-Object System.Windows.Forms.Label
	$box5Name.Location = New-Object System.Drawing.Size(10,120) 
	$box5Name.Size = New-Object System.Drawing.Size(80,20) 
	$box5Name.Text = $b5Text
	$objForm.Controls.Add($box5Name)
	
	$box5 = New-Object System.Windows.Forms.TextBox 
	$box5.Location = New-Object System.Drawing.Size(90,120) 
	$box5.Size = New-Object System.Drawing.Size(280,20) 
	$objForm.Controls.Add($box5) 
	
	$box6Name = New-Object System.Windows.Forms.Label
	$box6Name.Location = New-Object System.Drawing.Size(10,140) 
	$box6Name.Size = New-Object System.Drawing.Size(80,20) 
	$box6Name.Text = $b6Text
	$objForm.Controls.Add($box6Name)
	
	$box6 = New-Object System.Windows.Forms.TextBox 
	$box6.Location = New-Object System.Drawing.Size(90,140) 
	$box6.Size = New-Object System.Drawing.Size(280,20) 
	$objForm.Controls.Add($box6) 
	
	$objForm.Topmost = $True
	
	$objForm.Add_Shown({$objForm.Activate(); $box1.focus()})
	$formResult = $objForm.ShowDialog()
	
	IF ($formResult -eq [System.Windows.Forms.DialogResult]::Cancel)
	{
	BREAK
	}

	$Returns = @{
		'Box1' = $box1.text
		'Box2' = $box2.text
		'Box3' = $box3.text
		'Box4' = $box4.text
		'Box5' = $box5.text
		'Box6' = $box6.text
	}
	$Returns = [PSObject]$Returns
	$Returns
}

Function Invoke-5InpBox
{
	<#
	.SYNOPSIS
	Generate a customized form with five(5) user input boxes.
	
	.DESCRIPTION
	Generate a customized form with five(5) user input boxes.
	
	For a different number of input boxes try Invoke-1InpBox, Invoke-2InpBox, Invoke-3InpBox, etc
	
	.PARAMETER formTitle 
	The title that will appear at the top of the form.
	.PARAMETER formPrompt
	The message to the user.
	.PARAMETER b1Text
	The text that will show to the left of each input box.
		
	.EXAMPLE
	Invoke-2InpBox -formTitle "Input form title" -formPrompt "Please enter some info." -b1Text "Info here:" -b2Text "Also Here:"
	
	This will create a user input form, and return all input values to the terminal.
	
	.EXAMPLE
	$UserInput = Invoke-2InpBox -formTitle "Input form title" -formPrompt "Please enter some info." -b1Text "Info here:" -b2Text "Also Here:"
	
	This will create a user input form, and return all input values to a PSObject. In this case $UserInput.
	The values can then be returned with:
	$UserInput
	$UserInput.Box1
	$UserInput.box2
	#>
	
	[CmdletBinding()]
	Param
	(
		[parameter(Mandatory=$true)]
		$formTitle,
		[parameter(Mandatory=$true)]
		$formPrompt,
		[parameter(Mandatory=$true)]
		$b1Text,
		[parameter(Mandatory=$true)]
		$b2Text,
		[parameter(Mandatory=$true)]
		$b3Text,
		[parameter(Mandatory=$true)]
		$b4Text,
		[parameter(Mandatory=$true)]
		$b5Text
	)
	
	[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
	[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
	
	$objForm = New-Object System.Windows.Forms.Form 
	$objForm.Text = $formTitle
	$objForm.Size = New-Object System.Drawing.Size(400,220) 
	$objForm.StartPosition = "CenterScreen"
	
	$objForm.KeyPreview = $True
	$objForm.Add_KeyDown({
		if ($_.KeyCode -eq "Enter")
		{
			$objForm.Close()
		}
		ELSEIF ($_.KeyCode -eq "Escape")
		{
			BREAK
		}
	})
	
	$OKButton = New-Object System.Windows.Forms.Button
	$OKButton.Location = New-Object System.Drawing.Size(105,145)
	$OKButton.Size = New-Object System.Drawing.Size(75,23)
	$OKButton.Text = "OK"
	$OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
	$objForm.AcceptButton = $OKButton
	$objForm.Controls.Add($OKButton)
	
	$CancelButton = New-Object System.Windows.Forms.Button
	$CancelButton.Location = New-Object System.Drawing.Size(180,145)
	$CancelButton.Size = New-Object System.Drawing.Size(75,23)
	$CancelButton.Text = "Cancel"
	$CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
	$objForm.CancelButton = $CancelButton
	$objForm.Controls.Add($CancelButton)
	
	$objLabel = New-Object System.Windows.Forms.Label
	$objLabel.Location = New-Object System.Drawing.Size(20,20) 
	$objLabel.Size = New-Object System.Drawing.Size(380,20) 
	$objLabel.Text = $formPrompt
	$objForm.Controls.Add($objLabel)
	
	$box1Name = New-Object System.Windows.Forms.Label
	$box1Name.Location = New-Object System.Drawing.Size(10,40) 
	$box1Name.Size = New-Object System.Drawing.Size(80,20) 
	$box1Name.Text = $b1Text
	$objForm.Controls.Add($box1Name)

	$box1 = New-Object System.Windows.Forms.TextBox
	$box1.Location = New-Object System.Drawing.Size(90,40) 
	$box1.Size = New-Object System.Drawing.Size(280,15) 
	$objForm.Controls.Add($box1)	
	
	$box2Name = New-Object System.Windows.Forms.Label
	$box2Name.Location = New-Object System.Drawing.Size(10,60) 
	$box2Name.Size = New-Object System.Drawing.Size(80,20) 
	$box2Name.Text = $b2Text
	$objForm.Controls.Add($box2Name) 
	
	$box2 = New-Object System.Windows.Forms.TextBox
	$box2.Location = New-Object System.Drawing.Size(90,60) 
	$box2.Size = New-Object System.Drawing.Size(280,15) 
	$objForm.Controls.Add($box2) 
	
	$box3Name = New-Object System.Windows.Forms.Label
	$box3Name.Location = New-Object System.Drawing.Size(10,80) 
	$box3Name.Size = New-Object System.Drawing.Size(80,20) 
	$box3Name.Text = $b3Text
	$objForm.Controls.Add($box3Name)
	
	$box3 = New-Object System.Windows.Forms.TextBox 
	$box3.Location = New-Object System.Drawing.Size(90,80) 
	$box3.Size = New-Object System.Drawing.Size(280,20) 
	$objForm.Controls.Add($box3) 
	
	$box4Name = New-Object System.Windows.Forms.Label
	$box4Name.Location = New-Object System.Drawing.Size(10,100) 
	$box4Name.Size = New-Object System.Drawing.Size(80,20) 
	$box4Name.Text = $b4Text
	$objForm.Controls.Add($box4Name)
	
	$box4 = New-Object System.Windows.Forms.TextBox 
	$box4.Location = New-Object System.Drawing.Size(90,100) 
	$box4.Size = New-Object System.Drawing.Size(280,20) 
	$objForm.Controls.Add($box4) 
	
	$box5Name = New-Object System.Windows.Forms.Label
	$box5Name.Location = New-Object System.Drawing.Size(10,120) 
	$box5Name.Size = New-Object System.Drawing.Size(80,20) 
	$box5Name.Text = $b5Text
	$objForm.Controls.Add($box5Name)
	
	$box5 = New-Object System.Windows.Forms.TextBox 
	$box5.Location = New-Object System.Drawing.Size(90,120) 
	$box5.Size = New-Object System.Drawing.Size(280,20) 
	$objForm.Controls.Add($box5)
	
	$objForm.Topmost = $True
	
	$objForm.Add_Shown({$objForm.Activate(); $box1.focus()})
	$formResult = $objForm.ShowDialog()
	
	IF ($formResult -eq [System.Windows.Forms.DialogResult]::Cancel)
	{
	BREAK
	}

	$Returns = @{
		'Box1' = $box1.text
		'Box2' = $box2.text
		'Box3' = $box3.text
		'Box4' = $box4.text
		'Box5' = $box5.text
	}
	$Returns = [PSObject]$Returns
	$Returns
}

Function Invoke-4InpBox
{
	<#
	.SYNOPSIS
	Generate a customized form with four(4) user input boxes.
	
	.DESCRIPTION
	Generate a customized form with four(4) user input boxes.
	
	For a different number of input boxes try Invoke-1InpBox, Invoke-2InpBox, Invoke-3InpBox, etc
	
	.PARAMETER formTitle 
	The title that will appear at the top of the form.
	.PARAMETER formPrompt
	The message to the user.
	.PARAMETER b1Text
	The text that will show to the left of each input box.
		
	.EXAMPLE
	Invoke-2InpBox -formTitle "Input form title" -formPrompt "Please enter some info." -b1Text "Info here:" -b2Text "Also Here:"
	
	This will create a user input form, and return all input values to the terminal.
	
	.EXAMPLE
	$UserInput = Invoke-2InpBox -formTitle "Input form title" -formPrompt "Please enter some info." -b1Text "Info here:" -b2Text "Also Here:"
	
	This will create a user input form, and return all input values to a PSObject. In this case $UserInput.
	The values can then be returned with:
	$UserInput
	$UserInput.Box1
	$UserInput.box2
	#>
	
	[CmdletBinding()]
	Param
	(
		[parameter(Mandatory=$true)]
		$formTitle,
		[parameter(Mandatory=$true)]
		$formPrompt,
		[parameter(Mandatory=$true)]
		$b1Text,
		[parameter(Mandatory=$true)]
		$b2Text,
		[parameter(Mandatory=$true)]
		$b3Text,
		[parameter(Mandatory=$true)]
		$b4Text
	)
	
	[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
	[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
	
	$objForm = New-Object System.Windows.Forms.Form 
	$objForm.Text = $formTitle
	$objForm.Size = New-Object System.Drawing.Size(400,200) 
	$objForm.StartPosition = "CenterScreen"
	
	$objForm.KeyPreview = $True
	$objForm.Add_KeyDown({
		if ($_.KeyCode -eq "Enter")
		{
			$objForm.Close()
		}
		ELSEIF ($_.KeyCode -eq "Escape")
		{
			BREAK
		}
	})
	
	$OKButton = New-Object System.Windows.Forms.Button
	$OKButton.Location = New-Object System.Drawing.Size(105,125)
	$OKButton.Size = New-Object System.Drawing.Size(75,23)
	$OKButton.Text = "OK"
	$OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
	$objForm.AcceptButton = $OKButton
	$objForm.Controls.Add($OKButton)
	
	$CancelButton = New-Object System.Windows.Forms.Button
	$CancelButton.Location = New-Object System.Drawing.Size(180,125)
	$CancelButton.Size = New-Object System.Drawing.Size(75,23)
	$CancelButton.Text = "Cancel"
	$CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
	$objForm.CancelButton = $CancelButton
	$objForm.Controls.Add($CancelButton)
	
	$objLabel = New-Object System.Windows.Forms.Label
	$objLabel.Location = New-Object System.Drawing.Size(20,20) 
	$objLabel.Size = New-Object System.Drawing.Size(380,20) 
	$objLabel.Text = $formPrompt
	$objForm.Controls.Add($objLabel)
	
	$box1Name = New-Object System.Windows.Forms.Label
	$box1Name.Location = New-Object System.Drawing.Size(10,40) 
	$box1Name.Size = New-Object System.Drawing.Size(80,20) 
	$box1Name.Text = $b1Text
	$objForm.Controls.Add($box1Name)

	$box1 = New-Object System.Windows.Forms.TextBox
	$box1.Location = New-Object System.Drawing.Size(90,40) 
	$box1.Size = New-Object System.Drawing.Size(280,15) 
	$objForm.Controls.Add($box1)	
	
	$box2Name = New-Object System.Windows.Forms.Label
	$box2Name.Location = New-Object System.Drawing.Size(10,60) 
	$box2Name.Size = New-Object System.Drawing.Size(80,20) 
	$box2Name.Text = $b2Text
	$objForm.Controls.Add($box2Name) 
	
	$box2 = New-Object System.Windows.Forms.TextBox
	$box2.Location = New-Object System.Drawing.Size(90,60) 
	$box2.Size = New-Object System.Drawing.Size(280,15) 
	$objForm.Controls.Add($box2) 
	
	$box3Name = New-Object System.Windows.Forms.Label
	$box3Name.Location = New-Object System.Drawing.Size(10,80) 
	$box3Name.Size = New-Object System.Drawing.Size(80,20) 
	$box3Name.Text = $b3Text
	$objForm.Controls.Add($box3Name)
	
	$box3 = New-Object System.Windows.Forms.TextBox 
	$box3.Location = New-Object System.Drawing.Size(90,80) 
	$box3.Size = New-Object System.Drawing.Size(280,20) 
	$objForm.Controls.Add($box3) 
	
	$box4Name = New-Object System.Windows.Forms.Label
	$box4Name.Location = New-Object System.Drawing.Size(10,100) 
	$box4Name.Size = New-Object System.Drawing.Size(80,20) 
	$box4Name.Text = $b4Text
	$objForm.Controls.Add($box4Name)
	
	$box4 = New-Object System.Windows.Forms.TextBox 
	$box4.Location = New-Object System.Drawing.Size(90,100) 
	$box4.Size = New-Object System.Drawing.Size(280,20) 
	$objForm.Controls.Add($box4)
	
	$objForm.Topmost = $True
	
	$objForm.Add_Shown({$objForm.Activate(); $box1.focus()})
	$formResult = $objForm.ShowDialog()
	
	IF ($formResult -eq [System.Windows.Forms.DialogResult]::Cancel)
	{
	BREAK
	}

	$Returns = @{
		'Box1' = $box1.text
		'Box2' = $box2.text
		'Box3' = $box3.text
		'Box4' = $box4.text
	}
	$Returns = [PSObject]$Returns
	$Returns
}

Function Invoke-3InpBox
{
	<#
	.SYNOPSIS
	Generate a customized form with three(3) user input boxes.
	
	.DESCRIPTION
	Generate a customized form with three(3) user input boxes.
	
	For a different number of input boxes try Invoke-1InpBox, Invoke-2InpBox, Invoke-3InpBox, etc
	
	.PARAMETER formTitle 
	The title that will appear at the top of the form.
	.PARAMETER formPrompt
	The message to the user.
	.PARAMETER b1Text
	The text that will show to the left of each input box.
		
	.EXAMPLE
	Invoke-2InpBox -formTitle "Input form title" -formPrompt "Please enter some info." -b1Text "Info here:" -b2Text "Also Here:"
	
	This will create a user input form, and return all input values to the terminal.
	
	.EXAMPLE
	$UserInput = Invoke-2InpBox -formTitle "Input form title" -formPrompt "Please enter some info." -b1Text "Info here:" -b2Text "Also Here:"
	
	This will create a user input form, and return all input values to a PSObject. In this case $UserInput.
	The values can then be returned with:
	$UserInput
	$UserInput.Box1
	$UserInput.box2
	#>
	
	[CmdletBinding()]
	Param
	(
		[parameter(Mandatory=$true)]
		$formTitle,
		[parameter(Mandatory=$true)]
		$formPrompt,
		[parameter(Mandatory=$true)]
		$b1Text,
		[parameter(Mandatory=$true)]
		$b2Text,
		[parameter(Mandatory=$true)]
		$b3Text
	)
	
	[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
	[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
	
	$objForm = New-Object System.Windows.Forms.Form 
	$objForm.Text = $formTitle
	$objForm.Size = New-Object System.Drawing.Size(400,180) 
	$objForm.StartPosition = "CenterScreen"
	
	$objForm.KeyPreview = $True
	$objForm.Add_KeyDown({
		if ($_.KeyCode -eq "Enter")
		{
			$objForm.Close()
		}
		ELSEIF ($_.KeyCode -eq "Escape")
		{
			BREAK
		}
	})
	
	$OKButton = New-Object System.Windows.Forms.Button
	$OKButton.Location = New-Object System.Drawing.Size(105,105)
	$OKButton.Size = New-Object System.Drawing.Size(75,23)
	$OKButton.Text = "OK"
	$OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
	$objForm.AcceptButton = $OKButton
	$objForm.Controls.Add($OKButton)
	
	$CancelButton = New-Object System.Windows.Forms.Button
	$CancelButton.Location = New-Object System.Drawing.Size(180,105)
	$CancelButton.Size = New-Object System.Drawing.Size(75,23)
	$CancelButton.Text = "Cancel"
	$CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
	$objForm.CancelButton = $CancelButton
	$objForm.Controls.Add($CancelButton)
	
	$objLabel = New-Object System.Windows.Forms.Label
	$objLabel.Location = New-Object System.Drawing.Size(20,20) 
	$objLabel.Size = New-Object System.Drawing.Size(380,20) 
	$objLabel.Text = $formPrompt
	$objForm.Controls.Add($objLabel)
	
	$box1Name = New-Object System.Windows.Forms.Label
	$box1Name.Location = New-Object System.Drawing.Size(10,40) 
	$box1Name.Size = New-Object System.Drawing.Size(80,20) 
	$box1Name.Text = $b1Text
	$objForm.Controls.Add($box1Name)

	$box1 = New-Object System.Windows.Forms.TextBox
	$box1.Location = New-Object System.Drawing.Size(90,40) 
	$box1.Size = New-Object System.Drawing.Size(280,15) 
	$objForm.Controls.Add($box1)	
	
	$box2Name = New-Object System.Windows.Forms.Label
	$box2Name.Location = New-Object System.Drawing.Size(10,60) 
	$box2Name.Size = New-Object System.Drawing.Size(80,20) 
	$box2Name.Text = $b2Text
	$objForm.Controls.Add($box2Name) 
	
	$box2 = New-Object System.Windows.Forms.TextBox
	$box2.Location = New-Object System.Drawing.Size(90,60) 
	$box2.Size = New-Object System.Drawing.Size(280,15) 
	$objForm.Controls.Add($box2) 
	
	$box3Name = New-Object System.Windows.Forms.Label
	$box3Name.Location = New-Object System.Drawing.Size(10,80) 
	$box3Name.Size = New-Object System.Drawing.Size(80,20) 
	$box3Name.Text = $b3Text
	$objForm.Controls.Add($box3Name)
	
	$box3 = New-Object System.Windows.Forms.TextBox 
	$box3.Location = New-Object System.Drawing.Size(90,80) 
	$box3.Size = New-Object System.Drawing.Size(280,20) 
	$objForm.Controls.Add($box3)
	
	$objForm.Topmost = $True
	
	$objForm.Add_Shown({$objForm.Activate(); $box1.focus()})
	$formResult = $objForm.ShowDialog()
	
	IF ($formResult -eq [System.Windows.Forms.DialogResult]::Cancel)
	{
	BREAK
	}

	$Returns = @{
		'Box1' = $box1.text
		'Box2' = $box2.text
		'Box3' = $box3.text
	}
	$Returns = [PSObject]$Returns
	$Returns
}

Function Invoke-2InpBox
{
	<#
	.SYNOPSIS
	Generate a customized form with two(2) user input boxes.
	
	.DESCRIPTION
	Generate a customized form with two(2) user input boxes.
	
	For a different number of input boxes try Invoke-1InpBox, Invoke-2InpBox, Invoke-3InpBox, etc
	
	.PARAMETER formTitle 
	The title that will appear at the top of the form.
	.PARAMETER formPrompt
	The message to the user.
	.PARAMETER b1Text
	The text that will show to the left of each input box.
		
	.EXAMPLE
	Invoke-2InpBox -formTitle "Input form title" -formPrompt "Please enter some info." -b1Text "Info here:" -b2Text "Also Here:"
	
	This will create a user input form, and return all input values to the terminal.
	
	.EXAMPLE
	$UserInput = Invoke-2InpBox -formTitle "Input form title" -formPrompt "Please enter some info." -b1Text "Info here:" -b2Text "Also Here:"
	
	This will create a user input form, and return all input values to a PSObject. In this case $UserInput.
	The values can then be returned with:
	$UserInput
	$UserInput.Box1
	$UserInput.box2
	#>
	
	[CmdletBinding()]
	Param
	(
		[parameter(Mandatory=$true)]
		$formTitle,
		[parameter(Mandatory=$true)]
		$formPrompt,
		[parameter(Mandatory=$true)]
		$b1Text,
		[parameter(Mandatory=$true)]
		$b2Text
	)
	
	[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
	[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
	
	$objForm = New-Object System.Windows.Forms.Form 
	$objForm.Text = $formTitle
	$objForm.Size = New-Object System.Drawing.Size(400,160) 
	$objForm.StartPosition = "CenterScreen"
	
	$objForm.KeyPreview = $True
	$objForm.Add_KeyDown({
		if ($_.KeyCode -eq "Enter")
		{
			$objForm.Close()
		}
		ELSEIF ($_.KeyCode -eq "Escape")
		{
			BREAK
		}
	})
	
	$OKButton = New-Object System.Windows.Forms.Button
	$OKButton.Location = New-Object System.Drawing.Size(105,85)
	$OKButton.Size = New-Object System.Drawing.Size(75,23)
	$OKButton.Text = "OK"
	$OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
	$objForm.AcceptButton = $OKButton
	$objForm.Controls.Add($OKButton)
	
	$CancelButton = New-Object System.Windows.Forms.Button
	$CancelButton.Location = New-Object System.Drawing.Size(180,85)
	$CancelButton.Size = New-Object System.Drawing.Size(75,23)
	$CancelButton.Text = "Cancel"
	$CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
	$objForm.CancelButton = $CancelButton
	$objForm.Controls.Add($CancelButton)
	
	$objLabel = New-Object System.Windows.Forms.Label
	$objLabel.Location = New-Object System.Drawing.Size(20,20) 
	$objLabel.Size = New-Object System.Drawing.Size(380,20) 
	$objLabel.Text = $formPrompt
	$objForm.Controls.Add($objLabel)
	
	$box1Name = New-Object System.Windows.Forms.Label
	$box1Name.Location = New-Object System.Drawing.Size(10,40) 
	$box1Name.Size = New-Object System.Drawing.Size(80,20) 
	$box1Name.Text = $b1Text
	$objForm.Controls.Add($box1Name)

	$box1 = New-Object System.Windows.Forms.TextBox
	$box1.Location = New-Object System.Drawing.Size(90,40) 
	$box1.Size = New-Object System.Drawing.Size(280,15) 
	$objForm.Controls.Add($box1)	
	
	$box2Name = New-Object System.Windows.Forms.Label
	$box2Name.Location = New-Object System.Drawing.Size(10,60) 
	$box2Name.Size = New-Object System.Drawing.Size(80,20) 
	$box2Name.Text = $b2Text
	$objForm.Controls.Add($box2Name) 
	
	$box2 = New-Object System.Windows.Forms.TextBox
	$box2.Location = New-Object System.Drawing.Size(90,60) 
	$box2.Size = New-Object System.Drawing.Size(280,15) 
	$objForm.Controls.Add($box2)
	
	$objForm.Topmost = $True
	
	$objForm.Add_Shown({$objForm.Activate(); $box1.focus()})
	$formResult = $objForm.ShowDialog()
	
	IF ($formResult -eq [System.Windows.Forms.DialogResult]::Cancel)
	{
	BREAK
	}

	$Returns = @{
		'Box1' = $box1.text
		'Box2' = $box2.text
	}
	$Returns = [PSObject]$Returns
	$Returns
}

Function Invoke-1InpBox
{
	<#
	.SYNOPSIS
	Generate a customized form with one(1) user input boxes.
	
	.DESCRIPTION
	Generate a customized form with one(1) user input boxes.
	
	For a different number of input boxes try Invoke-1InpBox, Invoke-2InpBox, Invoke-3InpBox, etc
	
	.PARAMETER formTitle 
	The title that will appear at the top of the form.
	.PARAMETER formPrompt
	The message to the user.
	.PARAMETER b1Text
	The text that will show to the left of each input box.
		
	.EXAMPLE
	Invoke-2InpBox -formTitle "Input form title" -formPrompt "Please enter some info." -b1Text "Info here:" -b2Text "Also Here:"
	
	This will create a user input form, and return all input values to the terminal.
	
	.EXAMPLE
	$UserInput = Invoke-2InpBox -formTitle "Input form title" -formPrompt "Please enter some info." -b1Text "Info here:" -b2Text "Also Here:"
	
	This will create a user input form, and return all input values to a PSObject. In this case $UserInput.
	The values can then be returned with:
	$UserInput
	$UserInput.Box1
	$UserInput.box2
	#>
	
	[CmdletBinding()]
	Param
	(
		[parameter(Mandatory=$true)]
		$formTitle,
		[parameter(Mandatory=$true)]
		$formPrompt,
		[parameter(Mandatory=$true)]
		$b1Text
	)
	
	[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
	[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
	
	$objForm = New-Object System.Windows.Forms.Form 
	$objForm.Text = $formTitle
	$objForm.Size = New-Object System.Drawing.Size(400,140) 
	$objForm.StartPosition = "CenterScreen"
	
	$objForm.KeyPreview = $True
	$objForm.Add_KeyDown({
		if ($_.KeyCode -eq "Enter")
		{
			$objForm.Close()
		}
		ELSEIF ($_.KeyCode -eq "Escape")
		{
			BREAK
		}
	})
	
	$OKButton = New-Object System.Windows.Forms.Button
	$OKButton.Location = New-Object System.Drawing.Size(105,65)
	$OKButton.Size = New-Object System.Drawing.Size(75,23)
	$OKButton.Text = "OK"
	$OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
	$objForm.AcceptButton = $OKButton
	$objForm.Controls.Add($OKButton)
	
	$CancelButton = New-Object System.Windows.Forms.Button
	$CancelButton.Location = New-Object System.Drawing.Size(180,65)
	$CancelButton.Size = New-Object System.Drawing.Size(75,23)
	$CancelButton.Text = "Cancel"
	$CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
	$objForm.CancelButton = $CancelButton
	$objForm.Controls.Add($CancelButton)
	
	$objLabel = New-Object System.Windows.Forms.Label
	$objLabel.Location = New-Object System.Drawing.Size(20,20) 
	$objLabel.Size = New-Object System.Drawing.Size(380,20) 
	$objLabel.Text = $formPrompt
	$objForm.Controls.Add($objLabel)
	
	$box1Name = New-Object System.Windows.Forms.Label
	$box1Name.Location = New-Object System.Drawing.Size(10,40) 
	$box1Name.Size = New-Object System.Drawing.Size(80,20) 
	$box1Name.Text = $b1Text
	$objForm.Controls.Add($box1Name)

	$box1 = New-Object System.Windows.Forms.TextBox
	$box1.Location = New-Object System.Drawing.Size(90,40) 
	$box1.Size = New-Object System.Drawing.Size(280,15) 
	$objForm.Controls.Add($box1)	
	
	$objForm.Topmost = $True
	
	$objForm.Add_Shown({$objForm.Activate(); $box1.focus()})
	$formResult = $objForm.ShowDialog()
	
	IF ($formResult -eq [System.Windows.Forms.DialogResult]::Cancel)
	{
	BREAK
	}

	$Returns = @{
		'Box1' = $box1.text
	}
	$Returns = [PSObject]$Returns
	$Returns
}