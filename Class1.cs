
using System.Collections;

namespace Dusty.Net
{
    public enum Layer4Protocol { TCP, UDP }

    public class PortResult
    {
        public PortResult (string Server, Layer4Protocol Protocol, System.UInt16 Port, bool Success, string ResponseData)
        {
            this.Server = Server;
            this.Protocol = Protocol;
            this.Port = Port;
            this.Success = Success;
            this.ResponseData = ResponseData;
            this.IsUdp = (Protocol == Layer4Protocol.UDP);
            this.Summary = string.Format(
                "Connection {0} to {1} {2} on server {3}",
                (Success ? "succeeded" : "failed"),
                Protocol,
                Port,
                Server
                );
        }
        public string Server { get; private set; }
        public Layer4Protocol Protocol { get; private set; }
        public System.UInt16 Port { get; private set; }
        public bool Success { get; private set; }
        public bool IsUdp { get; private set; }
        public string ResponseData { get; private set; }
        public string Summary { get; private set; }
        public override string ToString()
        {
            return this.Summary;
        }
    }

    public class PortResultCollection : System.Collections.CollectionBase
    {
        public bool Success { get; private set; }
        public int CountSuccess { get; private set; }
        public string Summary { get; private set; }
        public override string ToString()
        {
            return this.Summary;
        }
        public void Add(PortResult portResult)
        {
            List.Add(portResult);
            Success = Success && portResult.Success;
            if (portResult.Success) { CountSuccess++; }
            Summary = string.Format(
                "{0}/{1} passed",
                Count,
                CountSuccess
                );
        }
        public void AddRange(PortResultCollection coll)
        {
            foreach (var portResult in coll)
            {
                Add(portResult);
            }
        }
        public new void RemoveAt(int index)
        {
            List.RemoveAt(index);
        }
        public void Remove(PortResult portResult)
        {
            List.Remove(portResult);
        }
        public PortResult Item(int Index)
        {
            // The appropriate item is retrieved from the List object and
            // explicitly cast to the Widget type, then returned to the 
            // caller.
            return (PortResult)List[Index];
        }
    }
}

