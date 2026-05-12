package com.follow.clash.service.modules

import android.app.Service
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkCapabilities.TRANSPORT_SATELLITE
import android.net.NetworkCapabilities.TRANSPORT_USB
import android.net.NetworkRequest
import android.os.Build
import androidx.core.content.getSystemService
import com.follow.clash.core.Core
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.net.Inet4Address
import java.net.Inet6Address
import java.net.InetAddress
import java.util.concurrent.ConcurrentHashMap

private data class NetworkInfo(
    @Volatile var losingMs: Long = 0, @Volatile var dnsList: List<InetAddress> = emptyList()
) {
    fun isAvailable(): Boolean = losingMs < System.currentTimeMillis()
}

class NetworkObserveModule(private val service: Service) : Module() {

    private val networkInfos = ConcurrentHashMap<Network, NetworkInfo>()
    private val connectivity by lazy {
        service.getSystemService<ConnectivityManager>()
    }
    private var preDnsList = listOf<String>()
    // S-14: Debounce job for onUpdateNetwork to prevent rapid-fire IPC during network handoff
    private var updateNetworkJob: Job? = null
    private val updateNetworkScope = CoroutineScope(Dispatchers.Default)

    private val request = NetworkRequest.Builder().apply {
        addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
        addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            addCapability(NetworkCapabilities.NET_CAPABILITY_FOREGROUND)
        }
        addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED)
    }.build()

    private val callback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            networkInfos[network] = NetworkInfo()
            scheduleUpdateNetwork()
            super.onAvailable(network)
        }

        override fun onLosing(network: Network, maxMsToLive: Int) {
            networkInfos[network]?.losingMs = System.currentTimeMillis() + maxMsToLive
            // F-03: Removed setUnderlyingNetworks(network) — passing a dying network
            // misinforms the system about which radio to keep active, wasting battery.
            // setUnderlyingNetworks is now called only from onUpdateNetwork() after
            // the debounce settles, with all available networks.
            scheduleUpdateNetwork()
            super.onLosing(network, maxMsToLive)
        }

        override fun onLost(network: Network) {
            networkInfos.remove(network)
            // F-03: Removed setUnderlyingNetworks(network) — passing a lost/dead network
            // causes the system to hold the wrong radio awake (e.g., Wi-Fi after switch
            // to cellular). The debounced onUpdateNetwork() handles this correctly.
            scheduleUpdateNetwork()
            super.onLost(network)
        }

        override fun onLinkPropertiesChanged(network: Network, linkProperties: LinkProperties) {
            networkInfos[network]?.dnsList = linkProperties.dnsServers
            // F-03: Removed setUnderlyingNetworks(network) — calling it per-callback
            // with only the triggering network is redundant and incomplete. The
            // debounced onUpdateNetwork() now handles this with ALL available networks.
            scheduleUpdateNetwork()
            super.onLinkPropertiesChanged(network, linkProperties)
        }
    }


    override fun onInstall() {
        onUpdateNetwork()
        connectivity?.registerNetworkCallback(request, callback)
    }

    private fun networkToInt(entry: Map.Entry<Network, NetworkInfo>): Int {
        val capabilities = connectivity?.getNetworkCapabilities(entry.key)
        return when {
            capabilities == null -> 100
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN) -> 90
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> 0
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> 1
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && capabilities.hasTransport(
                TRANSPORT_USB
            ) -> 2

            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_BLUETOOTH) -> 3
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> 4
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM && capabilities.hasTransport(
                TRANSPORT_SATELLITE
            ) -> 5

            else -> 20
        } + (if (entry.value.isAvailable()) 0 else 10)
    }

    // S-14: Debounced version of onUpdateNetwork (100ms) to prevent IPC storm
    // during rapid network handoff events (e.g., switching between Wi-Fi and cellular)
    fun scheduleUpdateNetwork() {
        updateNetworkJob?.cancel()
        updateNetworkJob = updateNetworkScope.launch {
            delay(100)
            onUpdateNetwork()
        }
    }

    private fun onUpdateNetwork() {
        val sorted = networkInfos.entries.sortedBy { networkToInt(it) }
        val bestEntry = sorted.firstOrNull()
        val dnsList = (bestEntry?.value?.dnsList
            ?: emptyList()).map { x -> x.asSocketAddressText(53) }
        if (dnsList == preDnsList) {
            // F-03: Even if DNS list unchanged, underlying networks may have changed
            // (e.g., Wi-Fi lost → cellular only). Still update underlying networks.
            // VPN-FIX-01: Skip setUnderlyingNetworks when no networks discovered yet
            // to avoid passing empty array (which tells Android the VPN has no
            // connectivity, causing immediate disconnection).
            setUnderlyingNetworks(sorted)
            return
        }
        preDnsList = dnsList
        Core.updateDNS(dnsList.toSet().joinToString(","))
        // F-03: Update underlying networks with all available networks after DNS update
        setUnderlyingNetworks(sorted)
    }

    // F-03: Pass ALL available networks to setUnderlyingNetworks so the system can
    // optimize radio usage correctly. Previously only passed the single triggering
    // network (which could be a dying/lost network), causing the system to hold
    // the wrong radio awake during network handoffs.
    //
    // VPN-FIX-02: setUnderlyingNetworks(emptyArray) tells Android the VPN has NO
    // underlying networks, causing Android to mark the VPN as having no internet
    // connectivity and immediately tearing it down. We must pass null instead,
    // which tells Android to determine underlying networks automatically.
    // Also skip the call entirely when no networks have been discovered yet,
    // since the network callback hasn't fired at that point.
    private fun setUnderlyingNetworks(sortedEntries: List<Map.Entry<Network, NetworkInfo>>) {
        if (service is android.net.VpnService) {
            val availableNetworks = sortedEntries
                .filter { it.value.isAvailable() }
                .map { it.key }
                .toTypedArray()
            try {
                // VPN-FIX-02: Pass null (not empty array) when no networks available.
                // null = "system decides" → VPN stays up
                // emptyArray = "no underlying networks" → VPN marked as no internet → killed
                service.setUnderlyingNetworks(availableNetworks.ifEmpty { null })
            } catch (_: Exception) {
                // Ignore on devices that don't support this
            }
        }
    }

    override fun onUninstall() {
        // S-18: Cancel debounce scope to prevent orphan coroutine calling into
        // a partially torn-down Go core after service destruction.
        updateNetworkScope.cancel()
        connectivity?.unregisterNetworkCallback(callback)
        networkInfos.clear()
        onUpdateNetwork()
    }
}

fun InetAddress.asSocketAddressText(port: Int): String {
    return when (this) {
        is Inet6Address -> "[${numericToTextFormat(this)}]:$port"

        is Inet4Address -> "${this.hostAddress}:$port"

        else -> throw IllegalArgumentException("Unsupported Inet type ${this.javaClass}")
    }
}

private fun numericToTextFormat(address: Inet6Address): String {
    val src = address.address
    val sb = StringBuilder(39)
    for (i in 0 until 8) {
        sb.append(
            Integer.toHexString(
                src[i shl 1].toInt() shl 8 and 0xff00 or (src[(i shl 1) + 1].toInt() and 0xff)
            )
        )
        if (i < 7) {
            sb.append(":")
        }
    }
    if (address.scopeId > 0) {
        sb.append("%")
        sb.append(address.scopeId)
    }
    return sb.toString()
}