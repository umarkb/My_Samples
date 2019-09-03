Function Check_Thresholds {
    param(
        $max_samples = 2,
        $interval_secs = 2,
        $disk_drive = "C:",
        [int[]]$cpu_pct_thresholds = (85,90),
        [int[]]$memory_pct_thresholds,
        [int[]]$disk_pct_thresholds,
        [int[]]$memory_mb_thresholds,
        [int[]]$disk_mb_thresholds
    );
 
    if (($memory_pct_thresholds -and $memory_mb_thresholds) -or ($disk_pct_thresholds -and $disk_mb_thresholds)) {
        return ConvertTo-Json @([pscustomobject][ordered]@{'error_message' = 'Invalid paramaters specified'});
    };
    if (!$memory_pct_thresholds -and !$memory_mb_thresholds) {
        [int[]]$memory_pct_thresholds = (85,90)
    }
    if (!$disk_pct_thresholds -and !$disk_mb_thresholds) {
        [int[]]$disk_pct_thresholds = (85,90)
    }
 
    $ErrorAction = "SilentlyContinue";
    $count = 0;
    $data_holder = @();
 
    while ($count -lt $max_samples) {       
        $thresholds = @();
 
        $mem_cim = Get-CimInstance Win32_OperatingSystem;
        $mem_total = $mem_cim.TotalVisibleMemorySize/1KB;
        $mem_free = $mem_cim.FreePhysicalMemory/1KB;
        $mem_used = $mem_total - $mem_free;
        $mem_perc = (($mem_used/$mem_total)*100);
        $cpu_perc = (Get-CimInstance Win32_Processor | measure -Property LoadPercentage -Average).Average;
        $disk_cim = Get-CimInstance Win32_LogicalDisk | where {$_.DeviceID -eq $disk_drive};
        $disk_total = $disk_cim.Size/1MB;
        $disk_free = $disk_cim.FreeSpace/1MB;
        $disk_used = $disk_total - $disk_free;
        $disk_used_percentage = ($disk_used/$disk_total)*100;
 
        $raw_processes = Get-CimInstance -Query "SELECT PercentProcessorTime,WorkingSetPrivate,Name from Win32_PerfRawData_PerfProc_Process where Name = '_total'";
        $cpu_raw_total = $raw_processes | select PercentProcessorTime -ExpandProperty PercentProcessorTime;
        $mem_raw_total = $raw_processes | select WorkingSetPrivate -ExpandProperty WorkingSetPrivate;
        
        $process_cim = Get-CimInstance -Query "SELECT PercentProcessorTime,WorkingSetPrivate,Name from Win32_PerfRawData_PerfProc_Process where Name != '_Total' AND Name != 'idle'";
 
        $data_object = [pscustomobject][ordered]@{
           'timestamp' = (Get-Date).ToString();
            'memory_free_mb' = [math]::Round($mem_free,2);
            'memory_used_pct' = [math]::Round($mem_perc,2);
            'memory_top_process_pct' = [math]::Round((($process_cim | sort -Property WorkingSetPrivate -Descending | select WorkingSetPrivate -First 1).WorkingSetPrivate/$mem_raw_total)*100,2);
            'memory_top_process_name' = ($process_cim | sort -Property WorkingSetPrivate -Descending | select Name -First 1).Name;
            'disk_free_mb' = [math]::Round($disk_free,2);
            'disk_used_pct' = [math]::Round($disk_used_percentage,2);
            'cpu_load_pct' = [math]::Round($cpu_perc,2);
            'cpu_top_process_pct' = [math]::Round((($process_cim | sort -Property PercentProcessorTime -Descending | select PercentProcessorTime -First 1).PercentProcessorTime/$cpu_raw_total)*100,2);
            'cpu_top_process_name' = ($process_cim | sort -Property PercentProcessorTime -Descending | select Name -First 1).Name;
        };
 
        $count += 1;
        $data_holder += $data_object;
        if ($count -lt $max_samples) {
            Start-Sleep -Seconds $interval_secs;
        };
    };
 
    $average_object = [pscustomobject][ordered]@{
        'memory_free_mb' = [math]::Round(($data_holder | measure -Property memory_free_mb -Average).Average,2);
        'memory_used_pct' = [math]::Round(($data_holder | measure -Property memory_used_pct -Average).Average,2);
        'disk_free_mb' = [math]::Round(($data_holder | measure -Property disk_free_mb -Average).Average,2);
        'disk_used_pct' = [math]::Round(($data_holder | measure -Property disk_used_pct -Average).Average,2);
        'cpu_load_pct' = [math]::Round(($data_holder | measure -Property cpu_load_pct -Average).Average,2);
        'memory_top_processes' = ($data_holder | select memory_top_process_name -ExpandProperty memory_top_process_name -Unique) -join ", ";
        'cpu_top_processes' = ($data_holder | select cpu_top_process_name -ExpandProperty cpu_top_process_name -Unique) -join ", ";
    };
 
    $threshold_object = [pscustomobject][ordered]@{
        'average_memory_used_pct' = $null;
        'average_disk_used_pct' = $null;
        'average_cpu_load_pct' = $null;
        'average_memory_free_mb' = $null;
        'average_disk_free_mb' = $null;
    };
 
    $cpu_check = switch ($average_object.cpu_load_pct) {
        ({$PSItem -ge $cpu_pct_thresholds[1]}) { 'CRITICAL'};
        ({$PSItem -lt $cpu_pct_thresholds[0]}) { 'PASS'};
        default {'WARNING'};
    };
    $threshold_object.average_cpu_load_pct = $cpu_check;
   
    if ($memory_mb_thresholds) {
        $mem_check = switch ($average_object.memory_free_mb) {
            ({$PSItem -lt $memory_mb_thresholds[0]}) { 'CRITICAL'};
            ({$PSItem -ge $memory_mb_thresholds[1]}) { 'PASS'};
            default {'WARNING'};
        };
        $threshold_object.average_memory_free_mb = $mem_check;
    }
    else {
        $mem_check = switch ($average_object.memory_used_pct) {
            ({$PSItem -ge $memory_pct_thresholds[1]}) { 'CRITICAL'};
            ({$PSItem -lt $memory_pct_thresholds[0]}) { 'PASS'};
            default {'WARNING'};
        };
        $threshold_object.average_memory_used_pct = $mem_check;
    };
 
    if ($disk_mb_thresholds) {
        $disk_check = switch ($average_object.disk_free_mb) {
            ({$PSItem -lt $disk_mb_thresholds[0]}) { 'CRITICAL'};
            ({$PSItem -ge $disk_mb_thresholds[1]}) { 'PASS'};
            default {'WARNING'};
        };
        $threshold_object.average_disk_free_mb = $disk_check;
    }
    else {
        $disk_check = switch ($average_object.disk_used_pct) {
            ({$PSItem -ge $disk_pct_thresholds[1]}) { 'CRITICAL'};
            ({$PSItem -lt $disk_pct_thresholds[0]}) { 'PASS'};
            default {'WARNING'};
        };
        $threshold_object.average_disk_used_pct = $disk_check;
    };
  
    $summary_object = [pscustomobject][ordered]@{
        'sample_data' = @($data_holder);
        'average_data' = @($average_object);
        'threshold_data' = @($threshold_object);
    };
 
    return ConvertTo-Json @($summary_object) -Depth 5;
};
