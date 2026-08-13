using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace MotoHub.Infrastructure.Persistence;

internal static class EntityConfigurationHelper
{
    public static void ConfigureEntity<T>(EntityTypeBuilder<T> entity, string table, bool softDelete = true) where T : class
    {
        entity.HasKey("Id");
        entity.ToTable(table);
        entity.Property<DateTimeOffset>("CreatedAt").IsRequired();
        entity.Property<byte[]>("RowVersion").IsRowVersion();
        if (softDelete)
        {
            entity.Property<bool>("IsDeleted").IsRequired();
        }
    }
}