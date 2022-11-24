import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as ec2 from 'aws-cdk-lib/aws-ec2';

export class TgwSingleExitStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const azs = cdk.Stack.of(this).availabilityZones;

    // -------------------------- VPCs and subnets --------------------------
    const privateConfig: ec2.SubnetConfiguration = {
      name: 'private',
      subnetType: ec2.SubnetType.PRIVATE_ISOLATED,
      // the properties below are optional
      cidrMask: 24,
    };

    const vpcEgress = new ec2.Vpc(this, 'egress-vpc', {
      cidr: "192.168.0.0/16",
      subnetConfiguration: [privateConfig],
      maxAzs: 4
    })

    const vpcSource = new ec2.Vpc(this, 'source-vpc', {
      cidr: "10.0.0.0/16",
      subnetConfiguration: [privateConfig],
      maxAzs: 1
    })

    const vpcDestination = new ec2.Vpc(this, 'destination-vpc', {
      cidr: "10.1.0.0/16",
      subnetConfiguration: [privateConfig],
      maxAzs: 1
    })

    const cfnVPCPeeringConnection = new ec2.CfnVPCPeeringConnection(this, 'vpc-peering-egress-destination', {
      peerVpcId: vpcEgress.vpcId,
      vpcId: vpcDestination.vpcId,
    });

    const subnets = vpcEgress.selectSubnets({subnetType: ec2.SubnetType.PRIVATE_ISOLATED}).subnets

    // -------------------------- Transit Gateway --------------------------

    const cfnTransitGateway = new ec2.CfnTransitGateway(this, 'transit-gateway',{
    });

    const cfnTransitGatewayAttachment = new ec2.CfnTransitGatewayAttachment(this, 'tgw-attachment-1', {
      subnetIds: [subnets[0].subnetId],
      transitGatewayId: cfnTransitGateway.,
      vpcId: 'vpcId',

      // the properties below are optional
      options: options,
      tags: [{
        key: 'key',
        value: 'value',
      }],
    });

    // -------------------------- NAT Gateway --------------------------

    const cfnNatGateway1 = new ec2.CfnNatGateway(this, 'nat-gw-1', {
      subnetId: subnets[0].subnetId,
      connectivityType: 'private',
    });

    // const cfnRoute = new ec2.CfnRoute(this, 'MyCfnRoute', {
    //   routeTableId: subnets[0].routeTable.routeTableId,
    //
    //   // the properties below are optional
    //   carrierGatewayId: 'carrierGatewayId',
    //   destinationCidrBlock: 'destinationCidrBlock',
    //   destinationIpv6CidrBlock: 'destinationIpv6CidrBlock',
    //   egressOnlyInternetGatewayId: 'egressOnlyInternetGatewayId',
    //   gatewayId: 'gatewayId',
    //   instanceId: 'instanceId',
    //   localGatewayId: 'localGatewayId',
    //   natGatewayId: 'natGatewayId',
    //   networkInterfaceId: 'networkInterfaceId',
    //   transitGatewayId: 'transitGatewayId',
    //   vpcEndpointId: 'vpcEndpointId',
    //   vpcPeeringConnectionId: 'vpcPeeringConnectionId',
    // });

    const cfnNatGateway2 = new ec2.CfnNatGateway(this, 'nat-gw-2', {
      subnetId: subnets[1].subnetId,
      connectivityType: 'private',
    });
  }
}
