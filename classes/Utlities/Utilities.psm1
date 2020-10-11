class Utilities {

    Utilities(){}

    [void]FormatConsole(){
        $psHost = Get-Host
        $Window = $psHost.UI.RawUI

        $bufferSize = $Window.BufferSize
        $bufferSize.Height = 3000
        $bufferSize.Width = 200
        $Window.BufferSize = $bufferSize

        $windowSize = $Window.WindowSize
        $windowSize.Height = $Window.MaxWindowSize.Height
        $windowSize.Width = $Window.MaxWindowSize.Width
        $Window.WindowSize = $windowSize
    }

    [char]RandomChar([char[]]$Chars){
        return [char]$Chars[$(Get-Random -Minimum 0 -Maximum $Chars.count)]
    }

    [string]RandomPassword([int]$Length, [bool]$AllowSpecial){       
        $special = 33..33 + 35..38 + 40..43 + 45..46 + 58..64 + 91 + 93..95
        $numbers = (48..57)
        $upper_case = (65..90)
        $lower_case = (97..122)
    
        $new_password = ""
    
        for($X = 0; $x -lt $Length; $x ++) {
            if($AllowSpecial){ $char_type = Get-Random -Minimum 0 -Maximum 3 }
            else{ $char_type = Get-Random -Minimum 1 -Maximum 3 }

            switch($char_type){
                0 { $new_password += $this.RandomChar($special) }
                1 { $new_password += $this.RandomChar($numbers) }
                2 { $new_password += $this.RandomChar($upper_case) }
                3 { $new_password += $this.RandomChar($lower_case) }
            }
        }
        return $new_password
    }

}