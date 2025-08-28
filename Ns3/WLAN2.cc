
// This Ns-3 file generate traffic on WLAN2 at rate of 1500B/25 ms, it uses 3 different application on each pair of STA



#include "ns3/applications-module.h"
#include "ns3/core-module.h"
#include "ns3/csma-module.h"
#include "ns3/internet-module.h"
#include "ns3/ipv4-global-routing-helper.h"
#include "ns3/mobility-module.h"
#include "ns3/network-module.h"
#include "ns3/point-to-point-module.h"
#include "ns3/tap-bridge-module.h"
#include "ns3/wifi-module.h"
#include "ns3/flow-monitor.h"
#include "ns3/flow-monitor-helper.h"
#include "ns3/ipv4-flow-classifier.h"


#include <fstream>
#include <iostream>

using namespace ns3;

NS_LOG_COMPONENT_DEFINE("TapDumbbellExample");



Time WLANm_channelBusyStartTime = Seconds(0);  // Start time of the current busy period
Time WLANm_totalChannelBusyTime = Seconds(0);  // Accumulated total channel busy time
std::vector<Time> WLANm_ongoingTransmissions;  // Track start times of ongoing transmissions
double WLANlastPrintTime = 0.0;


std::ofstream outputFile("WLAN1Occupancy.txt", std::ios::app);

void PhyTxBeginCallback(std::string context, Ptr<const Packet> packet, double txPowerDbm) {
    Time now = Simulator::Now();
     if (WLANm_ongoingTransmissions.empty()) {
            WLANm_channelBusyStartTime = now;  // Store the first transmission's start time
        }

        WLANm_ongoingTransmissions.push_back(now);  // Add to the list of active transmissions

   
}

void PhyTxEndCallback(std::string context, Ptr<const Packet> packet) {
   
    Time now = Simulator::Now();
    
    if (!WLANm_ongoingTransmissions.empty()) {
            WLANm_ongoingTransmissions.pop_back();  // Remove any transmission end

            if (WLANm_ongoingTransmissions.empty()) {
                // No more active transmissions, calculate the total busy time
                WLANm_totalChannelBusyTime += now - WLANm_channelBusyStartTime;
                WLANm_channelBusyStartTime = Seconds(0);  // Reset for the next period
             
            }
        }
       
     if (now.GetSeconds() - WLANlastPrintTime >= 1.0) {
           
        outputFile  << now.GetSeconds() << " " << WLANm_totalChannelBusyTime.GetSeconds()<<std::endl ;
        WLANlastPrintTime = now.GetSeconds();
        WLANm_totalChannelBusyTime=Seconds(0);
        
         }
    


}


int

main(int argc, char* argv[])
{
     

    CommandLine cmd(__FILE__);

    GlobalValue::Bind("SimulatorImplementationType", StringValue("ns3::RealtimeSimulatorImpl"));
    GlobalValue::Bind("ChecksumEnabled", BooleanValue(true));

    // Creating number of STAs and AP
    NodeContainer node; //WLAN2
    node.Create(13);

    // Network 2
    YansWifiPhyHelper wifiPhy;
    YansWifiChannelHelper wifiChannel = YansWifiChannelHelper::Default();
    wifiPhy.SetChannel(wifiChannel.Create());

    Ssid ssid2 = Ssid("Network-2");
    WifiHelper wifi;
    WifiMacHelper wifiMac;
    wifi.SetStandard (WIFI_STANDARD_80211ax);
    Config::SetDefault ("ns3::LogDistancePropagationLossModel::ReferenceLoss", DoubleValue (40));
    wifiPhy.Set ("ChannelSettings", StringValue ("{104 ,20, BAND_5GHZ, 0}")); //phy1 15,
    wifi.SetRemoteStationManager("ns3::ConstantRateWifiManager", "DataMode", StringValue("HtMcs7"), "ControlMode", StringValue("HtMcs0"));
    wifiMac.SetType("ns3::ApWifiMac", "Ssid", SsidValue(ssid2));
    NetDeviceContainer devicesWLAN = wifi.Install(wifiPhy, wifiMac, node.Get(0));
    wifi.SetRemoteStationManager("ns3::ConstantRateWifiManager", "DataMode", StringValue("HtMcs1"), "ControlMode", StringValue("HtMcs0"));

    wifiMac.SetType("ns3::StaWifiMac",
                    "Ssid",
                    SsidValue(ssid2),
                    "ActiveProbing",
                    BooleanValue(false));
    devicesWLAN.Add(wifi.Install(wifiPhy, wifiMac,NodeContainer(node.Get(3),node.Get(4),
                                                      node.Get(5),node.Get(6),node.Get(7),node.Get(8),
                                                        node.Get(9),node.Get(10),node.Get(11),node.Get(12))));
    
    //adding lower MCS, so to create higher lattency or contention as higher MCS would cause higher processing 
    wifi.SetRemoteStationManager("ns3::ConstantRateWifiManager", "DataMode", StringValue("HtMcs7"), "ControlMode", StringValue("HtMcs0"));
    devicesWLAN.Add(wifi.Install(wifiPhy, wifiMac,NodeContainer(node.Get(1), node.Get(2))));
  

    // MobilityHelper mobility;
    MobilityHelper mobility;
    Ptr<ListPositionAllocator> positionAlloc = CreateObject<ListPositionAllocator> ();
    mobility.SetMobilityModel ("ns3::ConstantPositionMobilityModel");
    mobility.SetMobilityModel("ns3::ConstantPositionMobilityModel");
    mobility.Install(node);
    float radius=10;
    positionAlloc->Add (Vector (0.0, 0.0, 0.0));//0
    positionAlloc->Add (Vector (-1*radius, 0.0, 0.0));//1
    positionAlloc->Add (Vector (radius, 0.0, 0.0));//2
    positionAlloc->Add (Vector (-1*radius/2,0.0, 0.0));//3
    positionAlloc->Add (Vector (radius/2,0.0, 0.0));//4
    positionAlloc->Add (Vector (-1*radius/3,0, 0.0));//5
    positionAlloc->Add (Vector (radius/3, 0, 0.0));//6
    positionAlloc->Add (Vector (-1*radius/4, 0, 0.0));//7
    positionAlloc->Add (Vector (radius/4, 0, 0.0));//8
    positionAlloc->Add (Vector (-1*radius/5,0, 0.0));//9
    positionAlloc->Add (Vector (1*radius/5, -1*radius/4, 0.0));//10
    positionAlloc->Add (Vector (-1*radius/6, 0, 0.0));//11
    positionAlloc->Add (Vector (radius/6,0, 0.0));//12

    //internet stack
    InternetStackHelper internetWLAN;
    internetWLAN.Install(node);
    //assing IP addresses
    Ipv4AddressHelper ipv4WLAN;
    ipv4WLAN.SetBase("192.168.60.0", "255.255.255.0");
    Ipv4InterfaceContainer interfacesWLAN = ipv4WLAN.Assign(devicesWLAN);

    //chaning seeds would cause totaly new set of random values for simulaiton, hence slightly different output would come
    SeedManager::SetSeed(1235); 
    RngSeedManager::SetRun(567);


    /////////////////Creating UDP traffic, each set of STA-AP have 3 Applications installlled///////////////////////////////////////////////////////
    int Number_STA=7; // number of STAS
    double intervalVal=0.025;//25ms
    int port=99;
    for (int i = 3; i <= Number_STA; i++) // Node (0)=AP,Node(1) =tap1 , Node(2)=tap2
    {
        
        for (int j = 1; j <= 3; j++)
        {
            
            port++;

            // Server setup
            ApplicationContainer serverApp1;
            UdpServerHelper server1(port);
            serverApp1 = server1.Install(node.Get(0));
            serverApp1.Start(Seconds(0));
            serverApp1.Stop(Seconds(300000));

            // Client setup
            UdpClientHelper client1(interfacesWLAN.GetAddress(0), port);
            client1.SetAttribute("MaxPackets", UintegerValue(4294967295u));
            client1.SetAttribute("Interval", TimeValue(Seconds(intervalVal))); // Use same interval for all 3 apps of the STA
            client1.SetAttribute("PacketSize", UintegerValue(1500));
            ApplicationContainer clientApp1 = client1.Install(node.Get(i));
            

            clientApp1.Start(Seconds(1/(j))); //random starting time for synchronization
            clientApp1.Stop(Seconds(300000));
        }
    }



    //creating tap devices

    TapBridgeHelper tapBridge;
    tapBridge.SetAttribute("Mode", StringValue("ConfigureLocal"));
    tapBridge.SetAttribute("DeviceName", StringValue("tap2"));
    tapBridge.Install(node.Get(1), devicesWLAN.Get(1));


    //    TapBridgeHelper tapBridge;
    tapBridge.SetAttribute("Mode", StringValue("ConfigureLocal"));
    tapBridge.SetAttribute("DeviceName", StringValue("tap4"));
    tapBridge.Install(node.Get(2), devicesWLAN.Get(2));


    // Assining routing
    Ipv4StaticRoutingHelper ipv4RoutingHelper;
    Ptr<Ipv4> ipv4Node = node.Get(1)->GetObject<Ipv4>();
    Ptr<Ipv4StaticRouting> staticRoutingNode = ipv4RoutingHelper.GetStaticRouting(ipv4Node);
    staticRoutingNode->SetDefaultRoute(interfacesWLAN.GetAddress(0), 1);
    Ipv4GlobalRoutingHelper::PopulateRoutingTables();


    Simulator::Stop(Seconds(800000));
    Config::Connect("/NodeList/*/DeviceList/*/$ns3::WifiNetDevice/Phy/PhyTxBegin", MakeCallback(&PhyTxBeginCallback));
    Config::Connect("/NodeList/*/DeviceList/*/$ns3::WifiNetDevice/Phy/PhyTxEnd", MakeCallback(&PhyTxEndCallback));

    for (uint32_t i = 0; i < NodeList::GetNNodes(); i++)
    {
    std::cout << "Node " << i << " -> ID: " << NodeList::GetNode(i)->GetId() << std::endl;
    }


    Simulator::Run();
    Simulator::Destroy();


return 0;
}
