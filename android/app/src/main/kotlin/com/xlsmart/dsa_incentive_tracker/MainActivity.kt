package com.xlsmart.dsa_incentive_tracker

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.TrafficStats
import android.net.wifi.WifiManager
import android.os.Build
import android.telephony.*
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.Inet4Address
import java.net.NetworkInterface
import java.util.Collections

class MainActivity : FlutterActivity() {
    private val channelTelephony = "com.aura.network/telephony"
    private val channelWifi = "com.aura.network/wifi"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Telephony Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelTelephony).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSimSlots" -> {
                    try {
                        result.success(getSimSlots())
                    } catch (e: Exception) {
                        result.error("SIM_ERROR", e.message, null)
                    }
                }
                "getCellInfo" -> {
                    try {
                        val subId = call.argument<Int>("subscriptionId")
                        val slotIndex = call.argument<Int>("slotIndex")
                        result.success(getCellInfo(subId, slotIndex))
                    } catch (e: Exception) {
                        result.error("CELL_ERROR", e.message, null)
                    }
                }
                "getTrafficStats" -> {
                    try {
                        result.success(getTrafficStats())
                    } catch (e: Exception) {
                        result.error("TRAFFIC_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // 2. WiFi Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelWifi).setMethodCallHandler { call, result ->
            when (call.method) {
                "getWifiInfo" -> {
                    try {
                        result.success(getWifiInfo())
                    } catch (e: Exception) {
                        result.error("WIFI_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getSimSlots(): List<Map<String, Any?>> {
        val simList = mutableListOf<Map<String, Any?>>()
        val hasPhoneState = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED

        if (hasPhoneState) {
            try {
                val subscriptionManager = getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager
                val activeList = subscriptionManager?.activeSubscriptionInfoList
                if (!activeList.isNullOrEmpty()) {
                    for (info in activeList) {
                        simList.add(
                            mapOf(
                                "subscriptionId" to info.subscriptionId,
                                "simSlotIndex" to info.simSlotIndex,
                                "carrierName" to (info.carrierName?.toString() ?: ""),
                                "displayName" to (info.displayName?.toString() ?: ""),
                                "iccId" to (info.iccId ?: ""),
                                "isActive" to true
                            )
                        )
                    }
                }
            } catch (_: Exception) {}
        }

        if (simList.isEmpty()) {
            val tm = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
            val simName = tm?.simOperatorName?.takeIf { it.isNotEmpty() } ?: "SIM 1"
            simList.add(
                mapOf(
                    "subscriptionId" to 1,
                    "simSlotIndex" to 0,
                    "carrierName" to simName,
                    "displayName" to simName,
                    "iccId" to "",
                    "isActive" to (tm?.simState == TelephonyManager.SIM_STATE_READY)
                )
            )
        }
        return simList
    }

    private fun getCellInfo(subscriptionId: Int?, slotIndex: Int?): Map<String, Any?> {
        var tm = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
        if (tm == null) {
            return mapOf(
                "subscriptionId" to subscriptionId,
                "networkType" to "UNKNOWN",
                "servingCell" to null,
                "neighborCells" to emptyList<Map<String, Any?>>()
            )
        }

        if (subscriptionId != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            try {
                val subTm = tm.createForSubscriptionId(subscriptionId)
                if (subTm != null) tm = subTm
            } catch (_: Exception) {}
        }

        val netTypeString = getNetworkTypeString(tm)
        val simOp = tm.simOperator
        val simOpName = tm.simOperatorName
        val netOp = tm.networkOperator
        val netOpName = tm.networkOperatorName

        var servingCell: Map<String, Any?>? = null
        val neighborCells = mutableListOf<Map<String, Any?>>()

        val hasFineLocation = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED

        if (hasFineLocation) {
            try {
                val allCells = tm.allCellInfo
                if (!allCells.isNullOrEmpty()) {
                    for (cellInfo in allCells) {
                        val cellMap = parseCellInfo(cellInfo) ?: continue
                        val isReg = cellInfo.isRegistered
                        if (isReg && servingCell == null) {
                            servingCell = cellMap
                        } else {
                            neighborCells.add(cellMap)
                        }
                    }
                }
            } catch (_: Exception) {}
        }

        // Fallback if no registered cell in allCellInfo, but network operator is detected
        if (servingCell == null && netTypeString != "UNKNOWN") {
            servingCell = mapOf(
                "cellType" to netTypeString,
                "isRegistered" to true,
                "connectionStatus" to "PRIMARY",
                "mcc" to if (netOp != null && netOp.length >= 3) netOp.substring(0, 3) else null,
                "mnc" to if (netOp != null && netOp.length >= 4) netOp.substring(3) else null
            )
        }

        return mapOf(
            "subscriptionId" to subscriptionId,
            "networkType" to netTypeString,
            "simOperator" to simOp,
            "simOperatorName" to simOpName,
            "networkOperator" to netOp,
            "networkOperatorName" to netOpName,
            "servingCell" to servingCell,
            "neighborCells" to neighborCells
        )
    }

    private fun parseCellInfo(cellInfo: CellInfo): Map<String, Any?>? {
        val map = mutableMapOf<String, Any?>()
        map["isRegistered"] = cellInfo.isRegistered
        map["connectionStatus"] = if (cellInfo.isRegistered) "PRIMARY" else "NONE"

        when (cellInfo) {
            is CellInfoLte -> {
                map["cellType"] = "LTE"
                val id = cellInfo.cellIdentity
                map["cellId"] = id.ci.takeIf { it in 0..268435455 }
                map["pci"] = id.pci.takeIf { it in 0..503 }
                map["tac"] = id.tac.takeIf { it in 0..65535 }
                map["arfcn"] = id.earfcn.takeIf { it in 1..262142 }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    map["bandwidth"] = id.bandwidth.takeIf { it > 0 }?.let { it / 1000 }
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    map["mcc"] = id.mccString
                    map["mnc"] = id.mncString
                } else {
                    map["mcc"] = id.mcc.takeIf { it != Int.MAX_VALUE }?.toString()
                    map["mnc"] = id.mnc.takeIf { it != Int.MAX_VALUE }?.toString()
                }

                val ss = cellInfo.cellSignalStrength
                map["rsrp"] = ss.rsrp.takeIf { it in -140..-44 }
                map["rsrq"] = ss.rsrq.takeIf { it in -30..-3 }
                map["sinr"] = ss.rssnr.takeIf { it in -30..40 }
                map["cqi"] = ss.cqi.takeIf { it in 1..15 }
                map["timingAdvance"] = ss.timingAdvance.takeIf { it in 0..1282 }
                map["dbm"] = ss.dbm.takeIf { it in -140..-40 }
                map["level"] = ss.level
            }
            is CellInfoNr -> {
                map["cellType"] = "NR"
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    val id = cellInfo.cellIdentity as? CellIdentityNr
                    if (id != null) {
                        map["cellId"] = id.nci.takeIf { it in 0L..68719476735L }?.toInt()
                        map["pci"] = id.pci.takeIf { it in 0..1007 }
                        map["tac"] = id.tac.takeIf { it in 0..16777215 }
                        map["arfcn"] = id.nrarfcn.takeIf { it > 0 }
                        map["mcc"] = id.mccString
                        map["mnc"] = id.mncString
                    }
                    val ss = cellInfo.cellSignalStrength as? CellSignalStrengthNr
                    if (ss != null) {
                        map["ssRsrp"] = ss.ssRsrp.takeIf { it in -140..-44 }
                        map["ssRsrq"] = ss.ssRsrq.takeIf { it in -30..-3 }
                        map["ssSinr"] = ss.ssSinr.takeIf { it in -30..40 }
                        map["csiRsrp"] = ss.csiRsrp.takeIf { it in -140..-44 }
                        map["csiRsrq"] = ss.csiRsrq.takeIf { it in -30..-3 }
                        map["csiSinr"] = ss.csiSinr.takeIf { it in -30..40 }
                        map["dbm"] = ss.dbm.takeIf { it in -140..-40 }
                        map["level"] = ss.level
                    }
                }
            }
            is CellInfoWcdma -> {
                map["cellType"] = "WCDMA"
                val id = cellInfo.cellIdentity
                map["cellId"] = id.cid.takeIf { it in 0..268435455 }
                map["pci"] = id.psc.takeIf { it in 0..511 }
                map["lac"] = id.lac.takeIf { it in 0..65535 }
                map["arfcn"] = id.uarfcn.takeIf { it > 0 }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    map["mcc"] = id.mccString
                    map["mnc"] = id.mncString
                } else {
                    map["mcc"] = id.mcc.takeIf { it != Int.MAX_VALUE }?.toString()
                    map["mnc"] = id.mnc.takeIf { it != Int.MAX_VALUE }?.toString()
                }
                val ss = cellInfo.cellSignalStrength
                map["dbm"] = ss.dbm.takeIf { it in -140..-40 }
                map["level"] = ss.level
            }
            is CellInfoGsm -> {
                map["cellType"] = "GSM"
                val id = cellInfo.cellIdentity
                map["cellId"] = id.cid.takeIf { it in 0..65535 }
                map["lac"] = id.lac.takeIf { it in 0..65535 }
                map["arfcn"] = id.arfcn.takeIf { it > 0 }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    map["mcc"] = id.mccString
                    map["mnc"] = id.mncString
                } else {
                    map["mcc"] = id.mcc.takeIf { it != Int.MAX_VALUE }?.toString()
                    map["mnc"] = id.mnc.takeIf { it != Int.MAX_VALUE }?.toString()
                }
                val ss = cellInfo.cellSignalStrength
                map["dbm"] = ss.dbm.takeIf { it in -140..-40 }
                map["level"] = ss.level
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    map["timingAdvance"] = ss.timingAdvance.takeIf { it in 0..219 }
                }
            }
            else -> return null
        }

        return map
    }

    private fun getNetworkTypeString(tm: TelephonyManager): String {
        val hasPhoneState = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED
        val type = if (hasPhoneState) {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) tm.dataNetworkType else tm.networkType
            } catch (_: Exception) {
                tm.networkType
            }
        } else {
            tm.networkType
        }

        return when (type) {
            TelephonyManager.NETWORK_TYPE_LTE -> "LTE"
            TelephonyManager.NETWORK_TYPE_NR -> "NR"
            TelephonyManager.NETWORK_TYPE_HSPAP,
            TelephonyManager.NETWORK_TYPE_HSPA,
            TelephonyManager.NETWORK_TYPE_HSDPA,
            TelephonyManager.NETWORK_TYPE_HSUPA,
            TelephonyManager.NETWORK_TYPE_UMTS -> "WCDMA"
            TelephonyManager.NETWORK_TYPE_EDGE -> "EDGE"
            TelephonyManager.NETWORK_TYPE_GPRS -> "GPRS"
            else -> "LTE"
        }
    }

    private fun getTrafficStats(): Map<String, Any> {
        return mapOf(
            "totalRxBytes" to TrafficStats.getTotalRxBytes(),
            "totalTxBytes" to TrafficStats.getTotalTxBytes(),
            "mobileRxBytes" to TrafficStats.getMobileRxBytes(),
            "mobileTxBytes" to TrafficStats.getMobileTxBytes(),
            "timestampMs" to System.currentTimeMillis()
        )
    }

    private fun getWifiInfo(): Map<String, Any?> {
        val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
        val info = wifiManager?.connectionInfo

        val isConnected = info != null && info.networkId != -1 && info.bssid != null && info.bssid != "02:00:00:00:00:00"

        if (!isConnected || info == null) {
            return mapOf(
                "ssid" to "",
                "bssid" to "",
                "rssiDbm" to -100,
                "linkSpeedMbps" to 0,
                "isConnected" to false
            )
        }

        var ssid = info.ssid ?: ""
        if (ssid.startsWith("\"") && ssid.endsWith("\"") && ssid.length > 1) {
            ssid = ssid.substring(1, ssid.length - 1)
        }
        if (ssid == "<unknown ssid>") ssid = "WiFi Terhubung"

        val bssid = info.bssid ?: ""
        val rssi = info.rssi
        val linkSpeed = info.linkSpeed
        val freq = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) info.frequency else 0

        val channel = when {
            freq in 2412..2484 -> (freq - 2407) / 5
            freq in 5000..5900 -> (freq - 5000) / 5
            freq in 5925..7125 -> (freq - 5950) / 5
            else -> null
        }

        val band = when {
            freq >= 5925 -> "6 GHz"
            freq >= 4900 -> "5 GHz"
            freq > 0 -> "2.4 GHz"
            else -> null
        }

        var ipAddress: String? = null
        val ipInt = info.ipAddress
        if (ipInt != 0) {
            ipAddress = String.format(
                "%d.%d.%d.%d",
                ipInt and 0xff,
                ipInt shr 8 and 0xff,
                ipInt shr 16 and 0xff,
                ipInt shr 24 and 0xff
            )
        } else {
            ipAddress = getLocalIpAddress()
        }

        var gateway: String? = null
        var subnetMask: String? = null
        try {
            val dhcp = wifiManager.dhcpInfo
            if (dhcp != null) {
                if (dhcp.gateway != 0) {
                    gateway = String.format(
                        "%d.%d.%d.%d",
                        dhcp.gateway and 0xff,
                        dhcp.gateway shr 8 and 0xff,
                        dhcp.gateway shr 16 and 0xff,
                        dhcp.gateway shr 24 and 0xff
                    )
                }
                if (dhcp.netmask != 0) {
                    subnetMask = String.format(
                        "%d.%d.%d.%d",
                        dhcp.netmask and 0xff,
                        dhcp.netmask shr 8 and 0xff,
                        dhcp.netmask shr 16 and 0xff,
                        dhcp.netmask shr 24 and 0xff
                    )
                }
            }
        } catch (_: Exception) {}

        return mapOf(
            "ssid" to ssid,
            "bssid" to bssid,
            "rssiDbm" to rssi,
            "linkSpeedMbps" to linkSpeed,
            "channel" to channel,
            "band" to band,
            "ipAddress" to ipAddress,
            "gateway" to gateway,
            "subnetMask" to subnetMask,
            "isConnected" to true
        )
    }

    private fun getLocalIpAddress(): String? {
        try {
            val interfaces = Collections.list(NetworkInterface.getNetworkInterfaces())
            for (intf in interfaces) {
                val addrs = Collections.list(intf.inetAddresses)
                for (addr in addrs) {
                    if (!addr.isLoopbackAddress && addr is Inet4Address) {
                        return addr.hostAddress
                    }
                }
            }
        } catch (_: Exception) {}
        return null
    }
}
