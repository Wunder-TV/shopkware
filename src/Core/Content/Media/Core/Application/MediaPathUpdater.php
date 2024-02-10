<?php declare(strict_types=1);

namespace Shopware\Core\Content\Media\Core\Application;

use Shopware\Core\Framework\Log\Package;

/**
 * Updater for the storage path of media and thumbnails
 *
 * The updater is responsible to update the path of media and thumbnails in the database.
 * The path has to be generated by the configured media path strategy and triggered when the media was uploaded and already stored in the database with the current state.
 * It will be triggered when the media was uploaded and already stored in the database with the current state.
 * The corresponding locations can be fetched by the `MediaLocationBuilder`.
 *
 * @final
 */
#[Package('buyers-experience')]
class MediaPathUpdater
{
    /**
     * @internal
     */
    public function __construct(
        private readonly AbstractMediaPathStrategy $strategy,
        private readonly MediaLocationBuilder $builder,
        private readonly MediaPathStorage $storage
    ) {
    }

    /**
     * Updates the path of media
     *
     * The `updateMedia` method is called when the media was uploaded and already stored in the database with the current state.
     * It is responsible to update the path of the media in the database.
     *
     * @param array<string> $ids
     */
    public function updateMedia(iterable $ids): void
    {
        if (empty($ids)) {
            return;
        }

        $ids = $ids instanceof \Traversable ? \iterator_to_array($ids) : $ids;

        $locations = $this->builder->media($ids);

        if (empty($locations)) {
            return;
        }

        $paths = $this->strategy->generate($locations);

        if (empty($paths)) {
            return;
        }

        $this->storage->media($paths);
    }

    /**
     * Updates the path of thumbnails
     *
     * The `updateThumbnails` method is called when the media was uploaded and already stored in the database with the current state.
     * It is responsible to update the path of the thumbnails in the database.
     *
     * @param array<string> $ids
     */
    public function updateThumbnails(iterable $ids): void
    {
        if (empty($ids)) {
            return;
        }

        $ids = $ids instanceof \Traversable ? \iterator_to_array($ids) : $ids;

        $locations = $this->builder->thumbnails($ids);
        if (empty($locations)) {
            return;
        }

        $paths = $this->strategy->generate($locations);
        if (empty($paths)) {
            return;
        }

        $this->storage->thumbnails($paths);
    }
}