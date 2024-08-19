Function Invoke-InputBox
{
	<#
	.SYNOPSIS
	Generate a customized form with up to nine(9) user input boxes.
	
	.DESCRIPTION
	Generate a customized form with up nine(9) user input boxes.
	
    .OUTPUTS
    An array object with each item of the array being the contents of one of the input fields collected from the user.
	
	.PARAMETER formTitle 
	The title that will appear at the top of the form.
	.PARAMETER formPrompt
	The message to the user. Such as: Please fill in each section below.
	.PARAMETER b1Text
    .PARAMETER b2Text
    .PARAMETER b3Text
    .PARAMETER b4Text
    .PARAMETER b5Text
    .PARAMETER b6Text
    .PARAMETER b7Text
    .PARAMETER b8Text
    .PARAMETER b9Text
	The text that will show to the left of each input box.
    .PARAMETER NumberOfBoxes
		
	.EXAMPLE
	Invoke-InputBox -formTitle "User Information" -formPrompt "Please fill in each section below." -NumberOfBoxes 4 -b1Text "First Name:" -b2Text "Last Name:" -b3Text "Phone Number:" -b4Text "Email:"
	
	This will create a user input form, and return all input values to the terminal.
	
	.EXAMPLE
	$UserInput = Invoke-InputBox -formTitle "User Information" -formPrompt "Please fill in each section below." -NumberOfBoxes 4 -b1Text "First Name:" -b2Text "Last Name:" -b3Text "Phone Number:" -b4Text "Email:"
	
	This will create a user input form, and return all input values to a PSObject. In this case $UserInput.
	The values can then be returned with:
	$UserInput
	$UserInput.Box1
	$UserInput.Box2
    etc
	#>
	
	[CmdletBinding()]
	Param
	(
		[parameter(Mandatory=$true)]
		[string]$formTitle,
		[parameter(Mandatory=$true)]
		[string]$formPrompt,
		[parameter(Mandatory=$true)]
		[string]$b1Text,
		[string]$b2Text,
		[string]$b3Text,
		[string]$b4Text,
		[string]$b5Text,
		[string]$b6Text,
		[string]$b7Text,
		[string]$b8Text,
		[string]$b9Text,
        [parameter(Mandatory=$true)]
        [int]$NumberOfBoxes = 1
	)
	Begin{
        [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
        [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
        
        $objForm = New-Object System.Windows.Forms.Form 
        $objForm.Text = $formTitle
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
        $OKButton.Size = New-Object System.Drawing.Size(75,23)
        $OKButton.Text = "OK"
        $OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $objForm.AcceptButton = $OKButton

        $CancelButton = New-Object System.Windows.Forms.Button
        $CancelButton.Size = New-Object System.Drawing.Size(75,23)
        $CancelButton.Text = "Cancel"
        $CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $objForm.CancelButton = $CancelButton

        $objLabel = New-Object System.Windows.Forms.Label
        $objLabel.Location = New-Object System.Drawing.Size(20,20) 
        $objLabel.Size = New-Object System.Drawing.Size(380,20) 
        $objLabel.Text = $formPrompt
        $objForm.Controls.Add($objLabel)

    }

	Process {
        switch ($NumberOfBoxes) {
            9 {
                $OKButton.Location = New-Object System.Drawing.Size(105,225)
                $objForm.Controls.Add($OKButton)
                
                $CancelButton.Location = New-Object System.Drawing.Size(180,225)
                $objForm.Controls.Add($CancelButton)

                $objForm.Size = New-Object System.Drawing.Size(400,300)
                
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
            }
            8{
                $OKButton.Location = New-Object System.Drawing.Size(105,205)
                $objForm.Controls.Add($OKButton)
                
                $CancelButton.Location = New-Object System.Drawing.Size(180,205)
                $objForm.Controls.Add($CancelButton)

                $objForm.Size = New-Object System.Drawing.Size(400,280)
                
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
            }
            7{
                $OKButton.Location = New-Object System.Drawing.Size(105,185)
                $objForm.Controls.Add($OKButton)
                
                $CancelButton.Location = New-Object System.Drawing.Size(180,185)
                $objForm.Controls.Add($CancelButton)

                $objForm.Size = New-Object System.Drawing.Size(400,260)

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
            }
            6{
                $OKButton.Location = New-Object System.Drawing.Size(105,165)
                $objForm.Controls.Add($OKButton)
                
                $CancelButton.Location = New-Object System.Drawing.Size(180,165)
                $objForm.Controls.Add($CancelButton)

                $objForm.Size = New-Object System.Drawing.Size(400,240)

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
            }
            5{
                $OKButton.Location = New-Object System.Drawing.Size(105,145)
                $objForm.Controls.Add($OKButton)
                
                $CancelButton.Location = New-Object System.Drawing.Size(180,145)
                $objForm.Controls.Add($CancelButton)

                $objForm.Size = New-Object System.Drawing.Size(400,220)

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
            }
            4{
                $OKButton.Location = New-Object System.Drawing.Size(105,125)
                $objForm.Controls.Add($OKButton)
                
                $CancelButton.Location = New-Object System.Drawing.Size(180,125)
                $objForm.Controls.Add($CancelButton)

                $objForm.Size = New-Object System.Drawing.Size(400,200)

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
            }
            3{
                $OKButton.Location = New-Object System.Drawing.Size(105,105)
                $objForm.Controls.Add($OKButton)
                
                $CancelButton.Location = New-Object System.Drawing.Size(180,105)
                $objForm.Controls.Add($CancelButton)

                $objForm.Size = New-Object System.Drawing.Size(400,180)

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
            }
            2{
                $OKButton.Location = New-Object System.Drawing.Size(105,85)
                $objForm.Controls.Add($OKButton)
                
                $CancelButton.Location = New-Object System.Drawing.Size(180,85)
                $objForm.Controls.Add($CancelButton)

                $objForm.Size = New-Object System.Drawing.Size(400,160)

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
            }
            1{
                $OKButton.Location = New-Object System.Drawing.Size(105,65)
                $objForm.Controls.Add($OKButton)
                
                $CancelButton.Location = New-Object System.Drawing.Size(180,65)
                $objForm.Controls.Add($CancelButton)

                $objForm.Size = New-Object System.Drawing.Size(400,120)

                $box1Name = New-Object System.Windows.Forms.Label
                $box1Name.Location = New-Object System.Drawing.Size(10,40) 
                $box1Name.Size = New-Object System.Drawing.Size(80,20) 
                $box1Name.Text = $b1Text
                $objForm.Controls.Add($box1Name)
            
                $box1 = New-Object System.Windows.Forms.TextBox
                $box1.Location = New-Object System.Drawing.Size(90,40) 
                $box1.Size = New-Object System.Drawing.Size(280,15) 
                $objForm.Controls.Add($box1)	
            }
            default{
                Write-Host "Invalid input. Please select 1 to 9."
            }
        }
    }
    end {
        $objForm.Topmost = $True
	
        $objForm.Add_Shown({$objForm.Activate(); $box1.focus()})
        $formResult = $objForm.ShowDialog()
        
        IF ($formResult -eq [System.Windows.Forms.DialogResult]::Cancel)
        {
        BREAK
        }
        switch ($NumberOfBoxes) {
            9{
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
            }
            8{
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
            }
            7{
                $Returns = @{
                    'Box1' = $box1.text
                    'Box2' = $box2.text
                    'Box3' = $box3.text
                    'Box4' = $box4.text
                    'Box5' = $box5.text
                    'Box6' = $box6.text
                    'Box7' = $box7.text
                }
            }
            6{
                $Returns = @{
                    'Box1' = $box1.text
                    'Box2' = $box2.text
                    'Box3' = $box3.text
                    'Box4' = $box4.text
                    'Box5' = $box5.text
                    'Box6' = $box6.text
                }
            }
            5{
                $Returns = @{
                    'Box1' = $box1.text
                    'Box2' = $box2.text
                    'Box3' = $box3.text
                    'Box4' = $box4.text
                    'Box5' = $box5.text
                }
            }
            4{
                $Returns = @{
                    'Box1' = $box1.text
                    'Box2' = $box2.text
                    'Box3' = $box3.text
                    'Box4' = $box4.text
                }
            }
            3{
                $Returns = @{
                    'Box1' = $box1.text
                    'Box2' = $box2.text
                    'Box3' = $box3.text
                }
            }
            2{
                $Returns = @{
                    'Box1' = $box1.text
                    'Box2' = $box2.text
                }
            }
            1{
                $Returns = @{
                    'Box1' = $box1.text
                }
            }
        }
        $Returns = [PSObject]$Returns
        return $Returns
    }
}