Function Get_Service_Data {
    param($name,$display_name);
    $services = Get-CimInstance win32_service;
    $os = Get-CimInstance win32_operatingsystem | Select-Object @{label='LastBootTime'; EXPRESSION={$_.lastbootuptime}};
    $ram = Get-CimInstance Win32_PhysicalMemory | Measure -Property Capacity -Sum | %{$_.sum/1Mb};
    $srvs_holder = @();
    $data_holder = @();
    if (($name -and $display_name) -or (!$name -and !$display_name)) {
      $object = New-Object PSobject;
      $object | Add-Member -NotePropertyName status -NotePropertyValue 'Missing/Invalid Parameters';
      return $object | ConvertTo-Json;
    }
    else {
        if ($name) {
            $srv_name = $name.Split(",");
            foreach ($sn in $srv_name) {
                $sn = $sn.Trim();
                $srv_check = ($services | ?{$_.Name -eq $sn});
                if ($srv_check) {
                    $srvs_holder += $srv_check;
                }
                else {
                    $hash_err = @{
                        'name' = $sn;
                        'status' = 'MISSING';
                    };
                    $srvs_holder += (New-Object PSobject -Property $hash_err);
                };
            };
        }
        else {
            $srv_dname = $display_name.Split(",");
            foreach ($sd in $srv_dname) {
                $sd = $sd.Trim();
                $srv_check = ($services | ?{$_.DisplayName -eq $sd});
                if ($srv_check) {
                    $srvs_holder += $srv_check;
                }
                else {
                    $hash_err = @{
                        'name' = $sd;
                        'status' = 'MISSING';
                    };
                    $srvs_holder += (New-Object PSobject -Property $hash_err);
                };
            };
        };
        if ($srvs_holder) {
            foreach ($srv in $srvs_holder) {              
                if ($srv.status -ne 'MISSING') {
                    $object = New-Object PSobject;
                    $object | Add-Member -MemberType NoteProperty -Name status -Value $srv.Status;
                    $object | Add-Member -MemberType NoteProperty -Name state -Value $srv.State.ToUpper();
                    $object | Add-Member -MemberType NoteProperty -Name name -Value $srv.Name;
                    $object | Add-Member -MemberType NoteProperty -Name display_name -Value $srv.DisplayName;
                    $object | Add-Member -MemberType NoteProperty -Name exe_path -Value $srv.PathName.Replace('"', '');
                    $object | Add-Member -MemberType NoteProperty -Name start_mode -Value $srv.StartMode.ToUpper();
                    $object | Add-Member -MemberType NoteProperty -Name running_as -Value $srv.StartName;
                    $object | Add-Member -MemberType NoteProperty -Name cpu_percent -Value '-';
                    $object | Add-Member -MemberType NoteProperty -Name memory_percent -Value '-';
                    $object | Add-Member -MemberType NoteProperty -Name memory_mb -Value '-';
                    $object | Add-Member -MemberType NoteProperty -Name process_name -Value '-';
                    $object | Add-Member -MemberType NoteProperty -Name process_id -Value '-';
                    $object | Add-Member -MemberType NoteProperty -Name start_time -Value '-';
                    if ($srv.ProcessId -ne 0) {
                        $process = Get-Process -Id $srv.ProcessId -ErrorAction SilentlyContinue;
                        $perf = Get-CimInstance Win32_PerfFormattedData_PerfProc_Process | ? {$_.IDProcess -eq $srv.ProcessId };
                        $object.memory_mb = [math]::Round($perf.WorkingSetPrivate/1Mb,2);
                        $object.memory_percent = [math]::Round(($perf.WorkingSetPrivate/1Mb)/$ram*100,2);
                        $object.cpu_percent = $perf.PercentProcessorTime;
                        $object.process_name = $process.Name;
                        $object.process_id   = $process.Id;
                        if ($object.start_mode -eq 'AUTO') {
                            $object.start_time = $os.LastBootTime.toString();
                        }
                        else {
                            $object.start_time = $process.StartTime.toString();
                        };      
                    };
                    $data_holder += $object;
                }
                else {
                    $data_holder += $srv;
                };
            };
            return (ConvertTo-Json @($data_holder));
        };
    };
};
