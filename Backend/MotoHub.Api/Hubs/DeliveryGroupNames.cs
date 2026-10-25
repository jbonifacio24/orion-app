namespace MotoHub.Api.Hubs;

public static class DeliveryGroupNames
{
    public static string Transaction(Guid transactionId) => $"delivery:{transactionId:N}";
}