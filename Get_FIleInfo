Function Get_FileInfo {
    param(
        [string[]]$paths,
        [ValidateSet('true', 'false')]$recursive
    );
    Function Rounder($obj) {
        return [math]::Round($obj,4);
    };
    $ErrorActionPreference = "SilentlyContinue";
    $data_holder = @();
    $md5 = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider;
    foreach ($f in $paths) {
        $object = [pscustomobject][ordered]@{
            'full_path' = $f.TrimEnd('\');
            'root_drive' = $null;
            'exists' = $false;
            'type' = 'file';
            'size_mb' = $null;
            'file_hash_md5' = $null;
            'directory' = $null;
            'created' = $null;
            'last_accessed' = $null;
            'last_modified' = $null;
            'child_recursive' = $false;
            'child_count' = $null;
            'child_items' = @([pscustomobject][ordered]@{
                'name' = $null;
                'type' = $null; 
                'size_mb' = $null; 
                'directory' = $null;
            };);
        };
        if (Test-Path $f) {
            $item = Get-Item -Path $f;
            $object.root_drive = $item.PSDrive.Root.TrimEnd('\');
            $object.exists = $true;   
            $object.created = $item.CreationTime.ToString();       
            $object.last_accessed = $item.LastAccessTime.ToString();
            $object.last_modified = $item.LastWriteTime.ToString();
            if ($item.PSIsContainer) {
                $child_holder = @();
                $child_items = switch($recursive) {
                    'true' {Get-ChildItem $item.FullName -Recurse -ErrorAction SilentlyContinue};
                    default {Get-ChildItem $item.FullName -ErrorAction SilentlyContinue};
                };
                $object.type = 'folder';
                $object.directory = (Get-Item $item.FullName).Parent.FullName.TrimEnd('\');
                $child_size = Rounder((Get-ChildItem $item.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum/1MB);
                $object.size_mb = Rounder($child_size/1MB);
                foreach ($c in $child_items) {
                    $child_object = [pscustomobject][ordered]@{
                        'name' = $c.Name;
                        'type' = 'file';     
                        'size_mb' = $null;       
                        'directory' = $null;         
                    };
                    if ($c.PSIsContainer) {
                        $child_object.type = 'folder';
                        $child_object.size_mb = Rounder((Get-ChildItem $c.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum/1MB);
                        $child_object.directory = $c.Parent.FullName.TrimEnd('\');
                    }
                    else {
                        $child_object.size_mb = Rounder($c.Length/1MB);
                        $child_object.directory = $c.DirectoryName.TrimEnd('\');
                    }
                    $child_holder += $child_object;                    
                };
                $object.child_items = $child_holder;
                $object.child_count =  ($child_items | measure).Count;
                $object.child_recursive = $recursive;
            }
            else {
                $file_base = [System.IO.File]::ReadAllBytes($item.FullName);
                $file_hash = [System.BitConverter]::ToString($md5.ComputeHash($file_base));
                $object.file_hash_md5 = $file_hash;
                $object.size_mb = Rounder($item.Length/1MB);
                $object.directory = $item.DirectoryName.TrimEnd('\');
            };
        };
        $data_holder += $object;
    };
    if ($data_holder) {
        if ($data_holder[0].child_count -eq 0) {
            $data_holder[0].child_items = @([pscustomobject][ordered]@{
                'name' = $null;
                'type' = $null;
                'size_mb' = $null;
                'directory' = $null;
            };);
        };
        return ConvertTo-Json @($data_holder) -Depth 3;
    }
    else {
        return ConvertTo-Json @([pscustomobject][ordered]@{        
            'full_path' = 'None provided';
            'root' = $null; 
            'exists' = $null;
            'type' = $null;
            'size_mb' = $null;
            'file_hash_md5' = $null;
            'directory' = $null;
            'created' = $null;
            'last_accessed' = $null;
            'last_modified' = $null;          
            'child_recursive' = $null;
            'child_count' = $null;
            'child_items' = @([pscustomobject][ordered]@{
                'name' = $null; 
                'type' = $null; 
                'size_mb' = $null; 
                'directory' = $null;
            };)
        };) -Depth 3;
    };  
};
